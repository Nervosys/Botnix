#! /bin/sh -e

export STORAGE=${STORAGE:-botnix}
export THREADS=${THREADS:-8}

azure-vhd-utils-for-go  upload --localvhdpath azure/disk.vhd  --stgaccountname "$STORAGE"  --stgaccountkey "$KEY" \
   --containername images --blobname botnix-unstable-nixops-updated.vhd --parallelism "$THREADS" --overwrite















