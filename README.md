# genprogressassets
Generates Xcode assets folders for animation frames

### How to use
Say you have PNG frames for animation and you want to have in Xcode Assets folder.
Suppose you PNGs are named like `FrameNNN.png` where NNN is frame number.

Go to the folder where frames are located and run:
`genprogressassets.pl --out-name progress`

`assets` folder should contain assets folders for each frame, named *progressNNN*.

Note PNGs are not copied, just linked.

### Distribution
There's `genprogressassets.exported.pl` file which is standalone version of the tool. Thanks to [fatpack](https://metacpan.org/pod/fatpack)


