# Step-by-step for GreatLake

## Requesting an account

- submit form to [https://teamdynamix.umich.edu/TDClient/30/Portal/Requests/TicketRequests/NewForm?ID=42&RequestorType=Service](https://teamdynamix.umich.edu/TDClient/30/Portal/Requests/TicketRequests/NewForm?ID=42&RequestorType=Service)
- Ask the administrator to put you in the slurm group (jungaocv0), or you will not be able to run anything, it will just say: *Invalid account or account/partition combination specified*

## Logging into the Slurm

- After creating your login, you can then access the cluster with the cheatsheet [https://docs.google.com/document/d/1wsr3yzkkojUMBCCneCz-l413xBzU-SZFAqcFrAAjttk/edit?tab=t.0#heading=h.kquo6lavnl0f](https://docs.google.com/document/d/1wsr3yzkkojUMBCCneCz-l413xBzU-SZFAqcFrAAjttk/edit?tab=t.0#heading=h.kquo6lavnl0f)
    - E.g. ssh *uniqname*@greatlakes.arc-ts.umich.edu (note: this one needs VPN if outside of campus [https://its.umich.edu/enterprise/wifi-networks/vpn](https://its.umich.edu/enterprise/wifi-networks/vpn))

## Creating an interactive Job

- Right now we can use A40 & V100 in the great lake cluster, and we have 11k free gpu hours to use there until July1st (it will renew after July 1st)
- For A40 gpus, we can ask for one gpu machine with the scripts below


------
## 4CPU-48MEM-1GPU

FOLLOW STRICTLY FOR **4CPU-48MEM-1GPU** RATIO FOR THE SPGPU JOBS


* The times are charged in the ratio of the maximum allocated resource to the above ratio.


    - i.e., the funding you burn with  4CPU-96MEM-1GPU is exactly the same as 8CPU-96MEM-2GPU, only because of the 96 Memory. So follow strictly with the above ratio

* You can play with 
```  my_job_estimate -c 4 -m 48g -g 1 -p spgpu -t 14-00:00:00```
to see the estimated charge related to your task/job.

------

***USE A TMUX SESSION TO LAUNCH AN INTERACTIVE JOB SO THAT YOU WON’T LOSE IT UPON CLOSING THE TERMINAL***


```bash
srun \
 --job-name=interactive \
 --mail-user=uniqname@umich.edu \
 --mail-type=FAIL \
 --ntasks-per-node=1 \
 --cpus-per-task=4 \
 --gres=gpu:1 \
 --mem-per-cpu=12GB \
 --time=02:00:00 \
 --account=jungaocv0 \
 --partition=spgpu \
 --pty /bin/bash
```

Then you should see a gl node connected to the terminal, this would be your gpu node.

Set up the SSH key-pair, then you can ssh gl15xx to the node.

### Personal Tip:

put the 

```bash
module load gcc
module load cuda
module load cudnn
```

in your ~/.bash_rc so that you don’t have to do this every time, but it takes some time to load it at each terminal open

## Connecting with VSCode/Cursor

In order to dev on vscode/cursor, instead of ssh, we need to use **Remote-Tunnel**

### vscode

- Remote (glxxxx node)
    1. Download code-cli from 
        
        ```bash
        curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz
        tar -xf vscode_cli.tar.gz
        
        ```
        
    2. Create tunnel and login with your account
        
        ```bash
        code tunnel
        ```
        
- Local machine
    1. Install remote-tunnel extension
    2. Connect to the Tunnel, log-in to your account, and connect to the tunnel session

### Cursor

The cursor is practically the same, except:

- Remote machine:
    - use [https://api2.cursor.sh/updates/download-latest?os=cli-alpine-x64](https://api2.cursor.sh/updates/download-latest?os=cli-alpine-x64)
    
    ```bash
    cursor tunnel
    ```
    
- local machine:
    
    Install the tunnel extension from VSIX:
    
     1. Download the tunnel extension from : [https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/remote-server/1.6.2025061709/vspackage](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/remote-server/1.6.2025061709/vspackage) 
    
     2. In the cursor extension, install from this VSIX

## Train something!

1. Install conda
2. try the resnet:

```bash
git clone  https://github.com/EricWang12/GreatLake_simple_resnet
bash run.sh
```

You should see it running on GPU.

## Submit a job

```bash
sbatch submit_job.sh
```

You can check the job status with `squeue --me`.

If everything goes well, you should see the job running and dump the output in the `logs/` folder.

###  multi-GPU example

```bash
sbatch submit_job_2gpu.sh
```

Pretty much the same as the single-GPU example, update CPU and mem according to the ratio mentioned above.



## STORAGE

TODO: More details and examples.

- [Locker](https://its.umich.edu/advanced-research-computing/storage/locker) (/nfs/locker/*volumename*) [large files, non-frequent]
- [Turbo storage](https://its.umich.edu/advanced-research-computing/storage/turbo) (/nfs/turbo/*volumename*) [Long-term slow storage see below for detail] *(Use this as primary storage [for now] )*
- [Scratch](https://its.umich.edu/advanced-research-computing/facilities-services) (/scratch/*account_root*/*account*/*uniqname)* temp fast dir (~10 TB) Inactive files purged after 60 days
- Home directory  (/home/*uniqname)* (80 GB quota)

### Home
Consider:
- Move your conda env and update default conda env path to turbo
- hyperlink your ~/.cache to turbo


### Turbo

- **/nfs/turbo/coe-jungaocv/** This is 10TB replicated and snapshoted storage, use for high-value stuff like the environment, processed data, code, etc.    
    - ** DON'T OVERFILL THIS !!!** This turbo gets snap-shot (which YOU cannot delete) every day at 1:30, so it is important not to overfill this storage. For example, you stored 8TB of ckpt today, and then it would get snap-shot into the /nfs/turbo/coe-jungaocv/.snapshot folder, and the storage becomes [10 - 16 = -6GB].  Even if you remove your 8TB ckpt afterwards, the snapshot will still exist and eat up 8 TB of storage, and can only be deleted by the IT admin upon request. SO DON'T OVERFILL THIS!!
 
- **/nfs/turbo/coe-jungaocv-turbo2** This storage is un-replicated and snapshot-disabled. Use for low-value stuff like datasets you could just download/verify again if lost/corrupted. 



## MISC

- It seems git doesn’t work well in the gl-nodes, use git with the login node
-
