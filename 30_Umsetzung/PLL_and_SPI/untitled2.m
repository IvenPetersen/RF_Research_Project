clear
freqMHz = 143;
divVal = 1;
divSel = 0;
REF_FREQ = 10;
MOD_VALUE = 4095;
while ((freqMHz * divVal) < 2200)   
    divSel = divSel + 1;
    divVal = bitshift(divVal,1); 
end
Fvco_Hz = freqMHz * divVal;
fPFD = REF_FREQ;
N = Fvco_Hz / fPFD;
INT  = floor(N);
FRACTION = (N - INT);
FRACTION = FRACTION * 10;
FRACTION = int16(FRACTION);
if(FRACTION == 1)
    FRAC = 1;
    MOD = 10;
end
if(FRACTION == 2)
    FRAC = 1;
    MOD = 5;
end
if(FRACTION == 3)
    FRAC = 3;
    MOD = 10;
end
if(FRACTION == 4)
    FRAC = 2;
    MOD = 5;
end
if(FRACTION == 5)
    FRAC = 1;
    MOD = 2;
end
if(FRACTION == 6)
    FRAC = 3;
    MOD = 5;
end
if(FRACTION == 7)
    FRAC = 7;
    MOD = 10;
end
if(FRACTION == 8)
    FRAC = 4;
    MOD = 5;
end
if(FRACTION == 9)
    FRAC = 9;
    MOD = 10;
end
