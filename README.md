# sudoku_9_to_36
perl puzzle solver

Input sizes:
9x9 with characters 1-9
16x16 with characters A-P
25x25 with characters A-Y
36x36 with characters 0-9,A-Z

The 36x36 grid is adapted to the current
character set from 
http://sudoku-drucken.de/36x36-sudoku-drucken-extrem-schwer-killer

To get one solution:
    ./solve.plx    16x16_three_solutions

To get every solution use "-a":
    ./solve.plx -a 16x16_three_solutions

The "perllib" directory should be in the
same directory as "solve.plx".
