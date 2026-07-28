"""Verilator driver.

Verilator has no reliable native-Windows build (the OSS CAD Suite Windows
package ships a Perl wrapper that cannot run from cmd.exe, and ``--build``
fails at link -- see YosysHQ/oss-cad-suite-build#142 and #173).  So this
module runs Verilator inside a pinned Docker image by default, and falls back
to a native ``verilator`` binary when one is on PATH (Linux/macOS/CI).

Everything else in ``scripts/`` goes through ``build()`` and ``run()`` so the
Docker incantation is written exactly once.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

#: Pinned so a Verilator release cannot silently change simulation results.
#: Digest of this tag at time of writing:
#: sha256:c531ae1e5da8e7293a2bd6793060c2bf484dac358746e69bcc3e689ec265b299
DEFAULT_IMAGE = "verilator/verilator:v5.050"

#: ``decoder.sv`` indexes ``out[pinNumber]`` with a ``byte`` and passes 3-bit
#: actuals to a ``bit[3:0]`` task argument; ``d_ff.sv`` has no `timescale.
#: All three are benign, but Verilator makes warnings fatal by default.  These
#: are listed explicitly rather than using ``-Wno-fatal`` so that a *new*
#: warning still breaks the build.
WAIVERS = ["-Wno-WIDTHTRUNC", "-Wno-WIDTHEXPAND", "-Wno-TIMESCALEMOD"]

#: Neither decoder.sv nor decoder_tb.sv carries a `timescale, and dff_tb.sv
#: declares 1ns/1ps -- mixing the two is an error without an explicit default.
TIMESCALE = "1ns/1ps"

BUILD_DIR = REPO / "sim" / "build"


class VerilatorError(RuntimeError):
    pass


def _native() -> str | None:
    """Path to a usable native verilator, or None."""
    if os.environ.get("VITERBI_FORCE_DOCKER"):
        return None
    return shutil.which("verilator")


def _docker_available() -> bool:
    if not shutil.which("docker"):
        return False
    try:
        subprocess.run(
            ["docker", "info"], capture_output=True, timeout=30, check=True
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return False
    return True


def backend() -> str:
    """``"native"`` or ``"docker"``; raises if neither is usable."""
    if _native():
        return "native"
    if _docker_available():
        return "docker"
    raise VerilatorError(
        "No Verilator available.\n"
        "  * Install Docker Desktop (the default path on Windows), or\n"
        "  * put a native `verilator` >= 5.020 on PATH (Linux/macOS/WSL2)."
    )


def _to_container(path: Path) -> str:
    """Map a repo-relative host path to its path inside the container."""
    rel = Path(path).resolve().relative_to(REPO)
    return "/work/" + rel.as_posix()


def _docker_prefix(image: str) -> list[str]:
    # MSYS_NO_PATHCONV stops Git Bash from rewriting /work into a Windows path.
    return [
        "docker", "run", "--rm",
        "-v", f"{REPO.as_posix()}:/work",
        "-w", "/work",
        "--entrypoint", "/bin/bash",
        image, "-c",
    ]


def _sh(argv: list[str], *, cwd: Path | None = None, check: bool = True,
        quiet: bool = False) -> subprocess.CompletedProcess:
    env = dict(os.environ, MSYS_NO_PATHCONV="1")
    proc = subprocess.run(
        argv, cwd=cwd, env=env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if not quiet and proc.stdout:
        sys.stdout.write(proc.stdout)
    if check and proc.returncode != 0:
        if quiet and proc.stdout:
            sys.stdout.write(proc.stdout)
        raise VerilatorError(f"command failed ({proc.returncode}): {' '.join(argv)}")
    return proc


def _exec(shell_cmd: str, *, image: str, check: bool = True,
          quiet: bool = False) -> subprocess.CompletedProcess:
    """Run a shell command either natively or inside the container."""
    if backend() == "native":
        return _sh(["/bin/bash", "-c", shell_cmd], cwd=REPO, check=check, quiet=quiet)
    return _sh(_docker_prefix(image) + [shell_cmd], check=check, quiet=quiet)


def build(top: str, sources: list[str], *, image: str = DEFAULT_IMAGE,
          extra: list[str] | None = None, quiet: bool = True) -> Path:
    """Verilate + compile ``sources`` into ``sim/build/<top>/<top>``.

    ``sources`` are repo-relative POSIX paths, e.g. ``["rtl/decoder.sv"]``.
    Returns the host path of the resulting executable.
    """
    mdir = f"sim/build/{top}"
    (REPO / mdir).mkdir(parents=True, exist_ok=True)

    argv = [
        "verilator", "--binary", "--timing", "--trace-vcd",
        "--timescale", TIMESCALE,
        *WAIVERS, *(extra or []),
        "--Mdir", mdir, "-o", top,
        *sources, "--top-module", top,
    ]
    _exec(" ".join(argv), image=image, quiet=quiet)

    exe = REPO / mdir / top
    if not exe.exists() and not exe.with_suffix(".exe").exists():
        raise VerilatorError(f"verilator produced no executable for {top}")
    return exe


def run(top: str, *, plusargs: dict[str, str] | None = None,
        image: str = DEFAULT_IMAGE, cwd_rel: str = ".",
        check: bool = True, quiet: bool = False) -> subprocess.CompletedProcess:
    """Run a previously built simulation binary.

    ``cwd_rel`` is the repo-relative directory the simulation runs in, which
    matters for the legacy testbenches: they hardcode ``$dumpfile("dump.vcd")``
    so the only way to place their VCD is to choose the working directory.
    """
    (REPO / cwd_rel).mkdir(parents=True, exist_ok=True)
    args = " ".join(f"+{k}={v}" for k, v in (plusargs or {}).items())
    exe = f"sim/build/{top}/{top}"

    if backend() == "native":
        cmd = f"cd {cwd_rel} && '{REPO.as_posix()}/{exe}' {args}"
    else:
        cmd = f"cd /work/{cwd_rel} && /work/{exe} {args}"
    return _exec(cmd, image=image, check=check, quiet=quiet)


def build_and_run(top: str, sources: list[str], **kw) -> subprocess.CompletedProcess:
    run_kw = {k: kw.pop(k) for k in ("plusargs", "cwd_rel", "check", "quiet")
              if k in kw}
    build(top, sources, **kw)
    return run(top, image=kw.get("image", DEFAULT_IMAGE), **run_kw)


if __name__ == "__main__":
    print(f"repo    : {REPO}")
    print(f"backend : {backend()}")
    print(f"image   : {DEFAULT_IMAGE}")
