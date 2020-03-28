#! /bin/bash
#$1=project location (e.g. karachi)
#$2=location port (e.g. 6020)
export location=${1:-unknown}
export port_location=${2:-22}
#batch_amount=${3:-2}
d=`date +%s`
batchName=batch_${location}_${d}
mkdir $batchName
echo "Key;Pass;Location;User;Comment" >>$batchName/${batchName}_index.csv
echo Creating batch $batchName
for i in {1..2}
do
    p=`pwgen -cnsB 8 1`
    num=$(($d + $i))
    f=$batchName/key_$num
    ssh-keygen -qa 100 -t ed25519 -N $p -C "${location} key_$num" -f ./$f
    cp -r ./relay $batchName/relay_${location}_key_${num}
    envsubst <$batchName/relay_${location}_key_${num}/conf/config.tpl >$batchName/relay_${location}_key_${num}/conf/config
    envsubst <$batchName/relay_${location}_key_${num}/tunnel.sh.tpl >$batchName/relay_${location}_key_${num}/tunnel.sh
    rm  $batchName/relay_${location}_key_${num}/*.tpl
    rm  $batchName/relay_${location}_key_${num}/conf/*.tpl
    echo "key_$num;$p;${localtion};;">>$batchName/${batchName}_index.csv
    echo `cat $f.pub`>>$batchName/pub_keys_to_add_to_unifield
    cp $f $batchName/relay_${location}_key_${num}/conf/.
    echo generated $location key $num
done
mkdir $batchName/key_pairs
mv $batchName/key* key_pairs/.