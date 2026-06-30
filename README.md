# ddmotion.sh

A shell script recreation of DOS program [hdmotion](http://hdmotion.pingerthinger.com) using dd in GNU/Linux.

## Features

Works on all block devices with varying sector sizes, including HDDs, SSDs, ODDs, and even FDDs (set PERT_RANGE to 0 for FDDs).

Applies random "perturbations" on each seek operation as a work-around of read caching on modern drives.

Adapts to terminal window width.

## Use

```bash
chmod +x ddmotion.sh
sudo ./ddmotion.sh
```

## Credits

This script was inspired by Jeremy Stanley's [hdmotion](http://hdmotion.pingerthinger.com) and 1157369's [hdmotion-for-windows](https://github.com/II57369/hdmotion-for-windows). It was mainly authored by **Gemma 4** and **DeepSeek-V4**, with the code audited and enhanced by me. <3

**Disclaimer:** This script was vibe coded together just for fun and provided "as is" with **NO WARRANTY**.

Feedbacks and contributions to this project are welcome! :D

## License

This script is released under the [GPLv3 license](https://www.gnu.org/licenses/gpl-3.0.html).
