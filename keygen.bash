#! /bin/bash
d=`date +%s`
batchName=batch_$d
mkdir $batchName
echo Creating batch $batchName
for i in {1..5}
do
p=`pwgen -cnsB 8 1`
num=$(($d + $i))
f=$batchName/key_$num
ssh-keygen -qa 100 -t ed25519 -N $p -C key_$num -f ./$f
echo key_$num,$p,`cat $f.pub` >>$batchName/index.csv
echo generated $num
done