// viterbi_2_1_4.cpp -- reference (2,1,4) Viterbi decoder.
//
// Originally a single hardcoded decode of one canonical word, with the trellis
// stages h1..h7 written out by hand in main() and the received bit pairs typed
// in as literals.  The trellis classes below are the author's, essentially
// unchanged; what changed is how they are driven:
//
//   * stages are built in a loop rather than unrolled, so the block length is a
//     parameter (`--bits`) instead of being baked into main();
//   * zero-tail termination is supported (`--terminate`), which forces the
//     traceback to start at state 0 instead of scanning for the best end state;
//   * cases are read from a file and each decode is checked against its
//     expected message, so the program reports pass/fail rather than printing a
//     trace for a human to read.
//
// One genuine bug was fixed, marked BUGFIX below in getFinalLowestState().
//
//     viterbi_2_1_4 --input vectors.txt --output results.csv
//     viterbi_2_1_4 --bits 7 --terminate --input vectors_term.txt
//
// Input format: one case per line, `received [expected]`, both as bit strings,
// MSB first.  Blank lines and lines starting with '#' are ignored.  Exit status
// is 0 only if every case with an expected message decoded to it.

#include <chrono>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace std;
using namespace std::chrono;

// The original code narrated every state it visited.  That is still available
// with --verbose, but it is far too much output for a sweep of a few thousand
// cases, so it is off by default.
static bool g_verbose = false;
#define TRACE(x) do { if (g_verbose) { cout << x; } } while (0)

class FinalHammingDistance {
public:
    int finalStates[8] = {0,0,0,0,0,0,0,0};
};
class CorrectSequence {
public:
    int bits[2];
    int decoded;
};
CorrectSequence bitSequence;
class HammingTable {
public:
    int recievedSequence[2];
    int aTransition[2];
    int bTransition[2];
    int cTransition[2];
    int dTransition[2];
    int eTransition[2];
    int fTransition[2];
    int gTransition[2];
    int hTransition[2];
    int previousHammingDistance[8];
    int step;
    FinalHammingDistance hammingDistances;


    HammingTable(int step, int bits[2]) {
        for (int i = 0; i < 8; i++) {
            this->previousHammingDistance[i] = 0;
        }
        this->step = step;
        recievedSequence[0] = bits[0];
        recievedSequence[1] = bits[1];

    }

    HammingTable(int previousValue[8], int step, int bits[2]) {
        for (int i = 0; i < 8; i++) {
            this->previousHammingDistance[i] = previousValue[i];
        }

        recievedSequence[0] = bits[0];
        recievedSequence[1] = bits[1];
        this->step = step;
    }

    void calculateForState(int state) {
        switch (state) {
        case 0:
            TRACE("executing case a" << endl);
            aTransition[0] = this->calculateDistanceForTransition(0, 0, this->previousHammingDistance[0]);
            aTransition[1] = this->calculateDistanceForTransition(1, 1, this->previousHammingDistance[0]);

            hammingDistances.finalStates[0] = aTransition[0]; //integer
            hammingDistances.finalStates[4] = aTransition[1]; //integer

            break; //calculated final hamming codes on state a
        case 1:
            TRACE("executing case b" << endl);
            bTransition[0] = this->calculateDistanceForTransition(1, 1, this->previousHammingDistance[1]);
            bTransition[1] = this->calculateDistanceForTransition(0, 0, this->previousHammingDistance[1]);
            if (bTransition[0] < hammingDistances.finalStates[0]) {
                hammingDistances.finalStates[0] = bTransition[0];
                aTransition[0] = -1;
            }
            else
            {
                bTransition[0] = -1;
            }
            if (bTransition[1] < hammingDistances.finalStates[4]) {
                hammingDistances.finalStates[4] = bTransition[1];
                aTransition[1] = -1;
            }
            else
            {
                bTransition[1] = -1;
            }
            break;
        case 2:
            TRACE("executing case c" << endl);
            cTransition[0] = this->calculateDistanceForTransition(1, 0, this->previousHammingDistance[2]);
            cTransition[1] = this->calculateDistanceForTransition(0, 1, this->previousHammingDistance[2]);

            hammingDistances.finalStates[1] = cTransition[0];
            hammingDistances.finalStates[5] = cTransition[1];
            break;
        case 3:
            TRACE("executing case d" << endl);
            dTransition[0] = this->calculateDistanceForTransition(0, 1, this->previousHammingDistance[3]);
            dTransition[1] = this->calculateDistanceForTransition(1, 0, this->previousHammingDistance[3]);
            if (dTransition[0] < hammingDistances.finalStates[1]) {
                hammingDistances.finalStates[1] = dTransition[0];
                cTransition[0] = -1;
            }
            else
            {
                dTransition[0] = -1;
            }
            if (dTransition[1] < hammingDistances.finalStates[5]) {
                hammingDistances.finalStates[5] = dTransition[1];
                cTransition[1] = -1;
            }
            else
            {
                dTransition[1] = -1;
            }
            break;
        case 4:
            TRACE("executing case e" << endl);
            eTransition[0] = this->calculateDistanceForTransition(1, 1, this->previousHammingDistance[4]);
            eTransition[1] = this->calculateDistanceForTransition(0, 0, this->previousHammingDistance[4]);
            hammingDistances.finalStates[2] = eTransition[0];
            hammingDistances.finalStates[6] = eTransition[1];
            break;
        case 5:
            TRACE("executing case f" << endl);
            fTransition[0] = this->calculateDistanceForTransition(0, 0, this->previousHammingDistance[5]);
            fTransition[1] = this->calculateDistanceForTransition(1, 1, this->previousHammingDistance[5]);
            if (fTransition[0] < hammingDistances.finalStates[2]) {
                hammingDistances.finalStates[2] = fTransition[0];
                eTransition[0] = -1;
            }
            else
            {
                fTransition[0] = -1;
            }
            if (fTransition[1] < hammingDistances.finalStates[6]) {
                hammingDistances.finalStates[6] = fTransition[1];
                eTransition[1] = -1;
            }
            else
            {
                fTransition[1] = -1;
            }
            break;
        case 6:
            TRACE("executing case g" << endl);
            gTransition[0] = this->calculateDistanceForTransition(0, 1, this->previousHammingDistance[6]);
            gTransition[1] = this->calculateDistanceForTransition(1, 0, this->previousHammingDistance[6]);
            hammingDistances.finalStates[3] = gTransition[0];
            hammingDistances.finalStates[7] = gTransition[1];
            break;
        case 7:
            TRACE("executing case h" << endl);
            hTransition[0] = this->calculateDistanceForTransition(1, 0, this->previousHammingDistance[7]);
            hTransition[1] = this->calculateDistanceForTransition(0, 1, this->previousHammingDistance[7]);
            if (hTransition[0] < hammingDistances.finalStates[3]) {
                TRACE("replacing d with hTransition[0] " << hTransition[0] << endl);
                hammingDistances.finalStates[3] = hTransition[0];
                gTransition[0] = -1;
            }
            else
            {
                hTransition[0] = -1;
            }
            if (hTransition[1] < hammingDistances.finalStates[7]) {
                hammingDistances.finalStates[7] = hTransition[1];
                gTransition[1] = -1;
            }
            else
            {
                hTransition[1] = -1;
            }
            break;
        }
    }

    int calculateDistanceForTransition(int firstBit, int secondBit, int previousDistance) {
        int distance = 0;
        if (this->recievedSequence[0] != firstBit) {
            distance++;
        }
        if (this->recievedSequence[1] != secondBit) {
            distance++;
        }
        return distance + previousDistance;
    }

    void computeHammingDistance() {
        // Only states reachable from the all-zero start state exist in the
        // first three stages, so the ladder opens up 1 -> 2 -> 4 -> 8 wide.
        if (this->step==1)
        {
            this->calculateForState(0);
        }
        if (this->step == 2)
        {
            this->calculateForState(0);
            this->calculateForState(4);
        }
        if (this->step == 3)
        {
            this->calculateForState(0);
            this->calculateForState(2);
            this->calculateForState(4);
            this->calculateForState(6);
        }
        if (this->step >= 4)
        {
            this->calculateForState(0);
            this->calculateForState(1);
            this->calculateForState(2);
            this->calculateForState(3);
            this->calculateForState(4);
            this->calculateForState(5);
            this->calculateForState(6);
            this->calculateForState(7);
        }

    }

    FinalHammingDistance getFinalHammingDistance() {
        return this->hammingDistances;
    }

    int getReturnPath(int state) {
        int previousState = 0;
        switch (state) {
        case 0:
            if (aTransition[0] != -1) {
                previousState = 0;
            }
            else {
                previousState = 1;
            }
            break;
        case 1:
            if (cTransition[0] != -1) {
                previousState = 2;
            }
            else {
                previousState = 3;
            }
            break;
        case 2:
            if (eTransition[0] != -1) {
                previousState = 4;
            }
            else {
                previousState = 5;
            }
            break;
        case 3:
            if (gTransition[0] != -1) {
                previousState = 6;
            }
            else {
                previousState = 7;
            }
            break;
        case 4:
            if (aTransition[1] != -1) {
                previousState = 0;
            }
            else {
                previousState = 1;
            }
            break;
        case 5:
            if (cTransition[1] != -1) {
                previousState = 2;
            }
            else {
                previousState = 3;
            }
            break;
        case 6:
            if (eTransition[1] != -1) {
                previousState = 4;
            }
            else {
                previousState = 5;
            }
            break;
        case 7:
            if (gTransition[1] != -1) {
                previousState = 6;
            }
            else {
                previousState = 7;
            }
            break;
        }
        return previousState;
    }
    int getFinalLowestState() {
        int lowestValue = this->hammingDistances.finalStates[0];
        int i = 0;
        // BUGFIX: this was `int lowest_state = lowestValue;` -- the *metric*,
        // where a state *index* belongs.  The loop below uses a strict `<`, so
        // when state 0 is the winner nothing ever assigns lowest_state and the
        // path metric was returned as if it were a state number.  It happened
        // to be right on an error-free word (metric 0, state 0) which is why
        // the canonical example still printed the correct message, but with any
        // channel error the traceback started from the wrong end state.
        // rtl/legacy/decoder.sv:660 does this correctly.
        int lowest_state = 0;
        for (i = 0; i < 8; i++) {
            if (this->hammingDistances.finalStates[i] < lowestValue) {
                lowestValue = this->hammingDistances.finalStates[i];
                TRACE("lowest value: " << lowestValue << endl);
                lowest_state = i;
            }
        }
        return lowest_state;
    }
};



CorrectSequence getSequence(int stateA, int stateB) {
    TRACE("returing bit sequence for states " << stateB << " to " << stateA << endl);
    if (stateB == 0 && stateA == 0) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 0;
    }
    else if (stateB == 0 && stateA == 1) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 0;
    }
    else if (stateB == 1 && stateA == 2) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 0;
    }
    else if (stateB == 1 && stateA == 3) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 0;
    }
    else if (stateB == 2 && stateA == 4) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 0;
    }
    else if (stateB == 2 && stateA == 5) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 0;
    }
    else if (stateB == 3 && stateA == 6) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 0;
    }
    else if (stateB == 3 && stateA == 7) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 0;
    }
    else if (stateB == 4 && stateA == 0) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 1;
    }
    else if (stateB == 4 && stateA == 1) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 1;
    }
    else if (stateB == 5 && stateA == 2) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 1;
    }
    else if (stateB == 5 && stateA == 3) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 1;
    }
    else if (stateB == 6 && stateA == 4) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 1;
    }
    else if (stateB == 6 && stateA == 5) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 1;
    }
    else if (stateB == 7 && stateA == 6) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 1;
    }
    else if (stateB == 7 && stateA == 7) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 1;
    }
    return bitSequence;
}


// ---------------------------------------------------------------------------
// Driver
// ---------------------------------------------------------------------------

struct Config {
    int  msgBits   = 7;
    bool terminate = false;
    string inPath;
    string outPath;
};

// The trellis stages main() used to write out by hand, built in a loop.  With
// `terminate` the encoder has flushed K-1 = 3 zeros through the register, so
// the path is known to end in state 0 and traceback starts there; otherwise it
// starts wherever the metric is lowest, which is what the original did.
static vector<int> decodeWord(const vector<int>& cw, int stages, bool terminate) {
    vector<HammingTable> tables;
    tables.reserve(stages);

    int previousValues[8] = {0,0,0,0,0,0,0,0};
    for (int s = 0; s < stages; s++) {
        int bits[2] = { cw[2 * s], cw[2 * s + 1] };
        if (s == 0) {
            tables.push_back(HammingTable(1, bits));
        } else {
            tables.push_back(HammingTable(previousValues, s + 1, bits));
        }
        tables.back().computeHammingDistance();
        FinalHammingDistance oldHam = tables.back().getFinalHammingDistance();
        for (int i = 0; i < 8; i++) {
            previousValues[i] = oldHam.finalStates[i];
        }
        if (g_verbose) {
            cout << "stage " << (s + 1) << " :";
            for (int i = 0; i < 8; i++) cout << " " << previousValues[i];
            cout << endl;
        }
    }

    int current = terminate ? 0 : tables.back().getFinalLowestState();
    TRACE("Final state: " << current << endl);

    vector<int> decoded(stages, 0);
    for (int s = stages - 1; s >= 0; s--) {
        int previous = tables[s].getReturnPath(current);
        CorrectSequence seq = getSequence(previous, current);
        decoded[s] = seq.decoded;
        current = previous;
    }
    return decoded;
}

static string toBits(const vector<int>& v, int n) {
    string s;
    for (int i = 0; i < n; i++) s += char('0' + v[i]);
    return s;
}

static void usage() {
    cout <<
      "usage: viterbi_2_1_4 [options]\n"
      "  -i, --input FILE    cases to decode (default: stdin)\n"
      "  -o, --output FILE   per-case CSV results (default: stdout)\n"
      "  -b, --bits N        message bits per block (default 7)\n"
      "  -t, --terminate     zero-tail terminated trellis: expects N+3 stages\n"
      "                      (2N+6 received bits) and tracebacks from state 0\n"
      "  -v, --verbose       print the original per-state trace\n"
      "  -h, --help\n"
      "\n"
      "Each input line is `received [expected]` as bit strings, MSB first.\n"
      "Blank lines and lines beginning with '#' are ignored.  Exit status is 0\n"
      "only when every case carrying an expected message decoded to it.\n";
}

int main(int argc, char** argv) {
    Config cfg;
    for (int i = 1; i < argc; i++) {
        string a = argv[i];
        auto next = [&]() -> string {
            if (i + 1 >= argc) { cerr << "missing value for " << a << endl; exit(2); }
            return argv[++i];
        };
        if      (a == "-i" || a == "--input")     cfg.inPath = next();
        else if (a == "-o" || a == "--output")    cfg.outPath = next();
        else if (a == "-b" || a == "--bits")      cfg.msgBits = stoi(next());
        else if (a == "-t" || a == "--terminate") cfg.terminate = true;
        else if (a == "-v" || a == "--verbose")   g_verbose = true;
        else if (a == "-h" || a == "--help")      { usage(); return 0; }
        else { cerr << "unknown option: " << a << endl; usage(); return 2; }
    }

    const int tail    = cfg.terminate ? 3 : 0;      // K - 1 flush bits
    const int stages  = cfg.msgBits + tail;
    const int cwBits  = 2 * stages;

    istream* in  = &cin;
    ifstream fin;
    if (!cfg.inPath.empty()) {
        fin.open(cfg.inPath);
        if (!fin) { cerr << "cannot open " << cfg.inPath << endl; return 2; }
        in = &fin;
    }
    ostream* out = &cout;
    ofstream fout;
    if (!cfg.outPath.empty()) {
        fout.open(cfg.outPath);
        if (!fout) { cerr << "cannot open " << cfg.outPath << endl; return 2; }
        out = &fout;
    }

    auto start = high_resolution_clock::now();
    *out << "case,received,decoded,expected,result\n";

    long total = 0, checked = 0, passed = 0;
    string line;
    while (getline(*in, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty() || line[0] == '#') continue;

        istringstream ls(line);
        string received, expected;
        ls >> received >> expected;
        if ((int)received.size() != cwBits) {
            cerr << "line " << (total + 1) << ": expected " << cwBits
                 << " received bits, got " << received.size() << endl;
            return 2;
        }

        vector<int> cw(cwBits);
        for (int i = 0; i < cwBits; i++) cw[i] = received[i] - '0';

        vector<int> decoded = decodeWord(cw, stages, cfg.terminate);
        string msg = toBits(decoded, cfg.msgBits);   // tail bits are not message

        const char* result = "-";
        if (!expected.empty()) {
            checked++;
            bool ok = (msg == expected);
            passed += ok;
            result = ok ? "PASS" : "FAIL";
        }
        *out << total << ',' << received << ',' << msg << ','
             << (expected.empty() ? "-" : expected) << ',' << result << '\n';
        total++;
    }

    auto duration = duration_cast<microseconds>(high_resolution_clock::now() - start);
    cerr << "decoded " << total << " cases in " << duration.count() << " us\n";
    if (checked) {
        cerr << (passed == checked ? "PASS" : "FAIL") << "  corrected "
             << passed << "/" << checked << "  ("
             << (100.0 * passed / checked) << "%)\n";
    }
    return (checked && passed != checked) ? 1 : 0;
}
