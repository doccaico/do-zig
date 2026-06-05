### Do (Windows only .-.)

### Required Softwares
- busybox64u (iconv)
- curl
- git
- less
- rg
- tar

### Build and Minimizing Binary Size
```sh
$ zig build -Doptimize=ReleaseSmall
$ upx --best --lzma zig-out\bin\do.exe
```

### Memo
- [Color](https://stackoverflow.com/questions/6297072/color-for-the-prompt-just-the-prompt-proper-in-cmd-exe-and-powershell)
