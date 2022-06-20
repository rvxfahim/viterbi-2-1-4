// viterbi 2 1 4.cpp : This file contains the 'main' function. Program execution begins and ends there.
//
#include <iostream>
#include <chrono>

using namespace std;
using namespace std::chrono;
class FinalHammingDistance {
public:
    int finalStates[8] = { -1,-1,-1,-1,-1,-1,-1,-1 };
    //int finalStates[4] ;
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
    int fTransition[3];
    int gTransition[2];
    int hTransition[2];
    int previousHammingDistance[8];
    int step;
    FinalHammingDistance hammingDistances;


    HammingTable(int step, int bits[2]) {
        for (int i = 0; i < 7; i++) {
            this->previousHammingDistance[i] = 0;
        }
        this->step = step;
        recievedSequence[0] = bits[0];
        recievedSequence[1] = bits[1];

    }

    HammingTable(int previousValue[8], int step, int bits[2]) {
        for (int i = 0; i < 7; i++) {
            this->previousHammingDistance[i] = previousValue[i];
        }

        recievedSequence[0] = bits[0];
        recievedSequence[1] = bits[1];
        this->step = step;
    }

    void calculateForState(int state) {
        switch (state) {
        case 0:   
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case a" << endl;
            cout << "Debug End:" << endl;
            aTransition[0] = this->calculateDistanceForTransition(0, 0, this->previousHammingDistance[0]);
            aTransition[1] = this->calculateDistanceForTransition(1, 1, this->previousHammingDistance[0]);
            
            hammingDistances.finalStates[0] = aTransition[0]; //integer
            hammingDistances.finalStates[4] = aTransition[1]; //integer
            
            break; //calculated final hamming codes on state a
        case 1:
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case b" << endl;
            cout << "Debug End:" << endl;
            bTransition[0] = this->calculateDistanceForTransition(1, 1, this->previousHammingDistance[1]);
            bTransition[1] = this->calculateDistanceForTransition(0, 0, this->previousHammingDistance[1]);
            //                cout<< "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            //                cout << "B0: " << bTransition[0] <<endl;
            //                cout <<"Debug End:"<<endl;
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
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case c" << endl;
            cout << "Debug End:" << endl;
            cTransition[0] = this->calculateDistanceForTransition(1, 0, this->previousHammingDistance[2]);
            cTransition[1] = this->calculateDistanceForTransition(0, 1, this->previousHammingDistance[2]);
            
            hammingDistances.finalStates[1] = cTransition[0];
            hammingDistances.finalStates[5] = cTransition[1];
            break;
        case 3:
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case d" << endl;
            cout << "Debug End:" << endl;
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
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case e" << endl;
            cout << "Debug End:" << endl;
            eTransition[0] = this->calculateDistanceForTransition(1, 1, this->previousHammingDistance[4]);
            eTransition[1] = this->calculateDistanceForTransition(0, 0, this->previousHammingDistance[4]);
            hammingDistances.finalStates[2] = eTransition[0];
            hammingDistances.finalStates[6] = eTransition[1];
            break;
        case 5:
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case d" << endl;
            cout << "Debug End:" << endl;
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
            if (dTransition[1] < hammingDistances.finalStates[6]) {
                hammingDistances.finalStates[6] = fTransition[1];
                eTransition[1] = -1;
            }
            else
            {
                fTransition[1] = -1;
            }
            break;
        case 6:
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case e" << endl;
            cout << "Debug End:" << endl;
            gTransition[0] = this->calculateDistanceForTransition(0, 1, this->previousHammingDistance[6]);
            gTransition[1] = this->calculateDistanceForTransition(1, 0, this->previousHammingDistance[6]);
            hammingDistances.finalStates[3] = gTransition[0];
            hammingDistances.finalStates[7] = gTransition[1];
            break;
        case 7:
            cout << "Debug:  " << endl;
            //                cout<< "Step: "<< this->step<< endl;
            //                cout<< "Previous Hamming: "<< this->previousHammingDistance[1]<< endl;
            cout << "executing case e" << endl;
            cout << "Debug End:" << endl;
            hTransition[0] = this->calculateDistanceForTransition(1, 0, this->previousHammingDistance[7]);
            hTransition[1] = this->calculateDistanceForTransition(0, 1, this->previousHammingDistance[7]);
            if (hTransition[0] < hammingDistances.finalStates[3]) {
                hammingDistances.finalStates[3] = hTransition[0];
                gTransition[0] = -1;
            }
            else
            {
                hTransition[0] = -1;
            }
            if (hTransition[1] < hammingDistances.finalStates[7]) {
                hammingDistances.finalStates[7] = fTransition[1];
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
        /*for (int i = 0; i < 7; i++) {
            this->calculateForState(i);
            if (this->step == 1 && i == 0) {
                break;
            }
            if (this->step == 2 && i == 1) {
                break;
            }
        }*/
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
        if (this->step >= 3)
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
                previousState = 2;
            }
            break;
        case 1:
            if (aTransition[1] != -1) {
                previousState = 0;
            }
            else {
                previousState = 2;
            }
            break;
        case 2:
            if (bTransition[0] != -1) {
                previousState = 1;
            }
            else {
                previousState = 3;
            }
            break;
        case 3:
            //cout << "B1:" << bTransition[1] << endl;
            if (bTransition[1] != -1) {
                previousState = 1;
            }
            else {
                previousState = 3;
            }
            break;
        }
        return previousState;
    }
    int getFinalLowestState() {
        int lowestValue = this->hammingDistances.finalStates[0];
        int i = 0;
        int lowest_state;
        for (i = 0; i < 7; i++) {
            if (this->hammingDistances.finalStates[i] < lowestValue) {
                lowestValue = this->hammingDistances.finalStates[i];
                cout << "debug start lowest value" << endl;
                cout << "lowest value: " << lowestValue << endl;
                lowest_state = i;
            }
        }
        //return i - 1;
        return lowest_state;
    }
};



CorrectSequence getSequence(int stateA, int stateB) {
    cout << "returing bit sequence for states " << stateB << " to " << stateA << endl;
    // if (stateA == 0 && stateB == 0) {
    //     bitSequence.bits[0] = 0;
    //     bitSequence.bits[1] = 0;
    // }
    // else if (stateA == 0 && stateB == 1) {
    //     bitSequence.bits[0] = 1;
    //     bitSequence.bits[1] = 1;
    // }
    // else if (stateA == 1 && stateB == 2) {
    //     bitSequence.bits[0] = 1;
    //     bitSequence.bits[1] = 0;
    //     cout << "bitsequence from b to c " << bitSequence.bits[0] << bitSequence.bits[1] << endl;
    // }
    // else if (stateA == 1 && stateB == 3) {

    //     bitSequence.bits[0] = 0;
    //     bitSequence.bits[1] = 1;
    //     cout << "bitsequence from b to d " << bitSequence.bits[0] << bitSequence.bits[1] << endl;
    // }
    // else if (stateA == 2 && stateB == 0) {
    //     bitSequence.bits[0] = 1;
    //     bitSequence.bits[1] = 1;
    // }
    // else if (stateA == 2 && stateB == 1) {
    //     bitSequence.bits[0] = 0;
    //     bitSequence.bits[1] = 0;
    // }
    // else if (stateA == 3 && stateB == 2) {
    //     bitSequence.bits[0] = 0;
    //     bitSequence.bits[1] = 1;
    // }
    // else if (stateA == 3 && stateB == 3) {
    //     bitSequence.bits[0] = 1;
    //     bitSequence.bits[1] = 0;
    // }
    if (stateB == 0 && stateA == 0) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 0;
    }
    else if (stateB == 0 && stateA == 2) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 0;
    }
    else if (stateB == 1 && stateA == 0) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 1;
    }
    else if (stateB == 1 && stateA == 2) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 1;
    }
    else if (stateB == 2 && stateA == 1) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 0;
    }
    else if (stateB == 2 && stateA == 3) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 0;
    }
    else if (stateB == 3 && stateA == 1) {
        bitSequence.bits[0] = 0;
        bitSequence.bits[1] = 1;
        bitSequence.decoded = 1;
    }
    else if (stateB == 3 && stateA == 3) {
        bitSequence.bits[0] = 1;
        bitSequence.bits[1] = 0;
        bitSequence.decoded = 1;
    }
    return bitSequence;
}

void main() {
    auto start = high_resolution_clock::now();
    cout << "hello" << endl;
    int bits[2] = { 1, 1 };
    HammingTable h1(1, bits);
    h1.computeHammingDistance();
    bits[0] = 0;
    bits[1] = 1;
    FinalHammingDistance oldHam = h1.getFinalHammingDistance();
    int previousValues[4] = { oldHam.finalStates[0], oldHam.finalStates[1], oldHam.finalStates[2],
                             oldHam.finalStates[3] };
    cout << "a: " << previousValues[0];
    cout << " b: " << previousValues[1];
    cout << " c: " << previousValues[2];
    cout << " d: " << previousValues[3] << endl;
    HammingTable h2(previousValues, 2, bits);
    h2.computeHammingDistance();
    //bits[0] = 0;
    //bits[1] = 1;
    oldHam = h2.getFinalHammingDistance();
    previousValues[0] = oldHam.finalStates[0];
    previousValues[1] = oldHam.finalStates[1];
    previousValues[2] = oldHam.finalStates[2];
    previousValues[3] = oldHam.finalStates[3];
    cout << "a: " << previousValues[0];
    cout << " b: " << previousValues[1];
    cout << " c: " << previousValues[2];
    cout << " d: " << previousValues[3] << endl;


    bits[0] = 0;
    bits[1] = 1;
    HammingTable h3(previousValues, 3, bits);
    h3.computeHammingDistance();
    oldHam = h3.getFinalHammingDistance();
    previousValues[0] = oldHam.finalStates[0];
    previousValues[1] = oldHam.finalStates[1];
    previousValues[2] = oldHam.finalStates[2];
    previousValues[3] = oldHam.finalStates[3];
    cout << "a:" << previousValues[0];
    cout << " b: " << previousValues[1];
    cout << " c: " << previousValues[2];
    cout << " d: " << previousValues[3] << endl;


    bits[0] = 1;
    bits[1] = 0;
    HammingTable h4(previousValues, 4, bits);
    h4.computeHammingDistance();
    oldHam = h4.getFinalHammingDistance();
    previousValues[0] = oldHam.finalStates[0];
    previousValues[1] = oldHam.finalStates[1];
    previousValues[2] = oldHam.finalStates[2];
    previousValues[3] = oldHam.finalStates[3];
    cout << "a:" << previousValues[0];
    cout << " b: " << previousValues[1];
    cout << " c: " << previousValues[2];
    cout << " d: " << previousValues[3] << endl;


    bits[0] = 0;
    bits[1] = 1;
    HammingTable h5(previousValues, 5, bits);
    h5.computeHammingDistance();
    oldHam = h5.getFinalHammingDistance();
    previousValues[0] = oldHam.finalStates[0];
    previousValues[1] = oldHam.finalStates[1];
    previousValues[2] = oldHam.finalStates[2];
    previousValues[3] = oldHam.finalStates[3];
    cout << "a:" << previousValues[0];
    cout << " b: " << previousValues[1];
    cout << " c: " << previousValues[2];
    cout << " d: " << previousValues[3] << endl;
    CorrectSequence sequenceBits;
    cout << "Final Lowest State: " << h5.getFinalLowestState() << endl;
    int previousState = h5.getReturnPath(h5.getFinalLowestState());
    cout << "Previous Lowest State: " << previousState << endl;
    sequenceBits = getSequence(previousState, h5.getFinalLowestState());
    cout << "Bits: " << sequenceBits.bits[0] << sequenceBits.bits[1] << endl;
    cout << "Bits: " << sequenceBits.decoded << endl;
    int newState = h4.getReturnPath(previousState);
    cout << "Previous Lowest State: " << newState << endl;
    //sequenceBits = getSequence(previousState, newState);
    sequenceBits = getSequence(newState, previousState);
    cout << "Bits: " << sequenceBits.bits[0] << sequenceBits.bits[1] << endl;
    cout << "Bits: " << sequenceBits.decoded << endl;
    previousState = newState;
    newState = h3.getReturnPath(previousState);
    cout << "Previous Lowest State: " << newState << endl;
    sequenceBits = getSequence(newState, previousState);
    cout << "Bits: " << sequenceBits.bits[0] << sequenceBits.bits[1] << endl;
    cout << "Bits: " << sequenceBits.decoded << endl;
    previousState = newState;
    newState = h2.getReturnPath(previousState);
    cout << "Previous Lowest State: " << newState << endl;
    sequenceBits = getSequence(newState, previousState);
    cout << "Bits: " << sequenceBits.bits[0] << sequenceBits.bits[1] << endl;
    cout << "Bits: " << sequenceBits.decoded << endl;
    previousState = newState;
    newState = h1.getReturnPath(previousState);
    cout << "Previous Lowest State: " << newState << endl;
    sequenceBits = getSequence(newState, previousState);
    cout << "Bits: " << sequenceBits.bits[0] << sequenceBits.bits[1] << endl;
    cout << "Bits: " << sequenceBits.decoded << endl;

    auto stop = high_resolution_clock::now();
    auto duration = duration_cast<microseconds>(stop - start);
    cout << duration.count() << endl;
}