# pulito

A Bash script to back up and scan AWS S3 buckets for viruses using ClamAV.

## Features

- Mounts S3 buckets locally using `s3fs-fuse`
- Syncs bucket contents to a local directory with `rsync`
- Scans files for viruses with `clamscan`
- Logs all operations with timestamps
- Handles errors and cleans up mounts automatically

## Requirements

- Bash (tested on Linux)
- [s3fs-fuse](https://github.com/s3fs-fuse/s3fs-fuse)
- [rsync](https://rsync.samba.org/)
- [ClamAV](https://www.clamav.net/)
- AWS credentials configured for `s3fs`

## Usage

```sh
[pulito.sh] S3BUCKETNAME
```
