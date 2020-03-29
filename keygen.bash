#! /bin/bash
# dependencies : pwgen openssh
#$1=project location (e.g. karachi)
#$2=location port (e.g. 6020)
#$3=number of keys to generate [5]
#$4=user login [uf_location]
export location=${1:-unknown}
export port_location=${2:-22}
batch_amount=${3:-5}
export userlogin=${4:-uf_$1}
d=`date +%s`
#d=$(uuidgen)
batchName=batch_${location}_${d}
mkdir $batchName
echo "Key;Pass;Location;User;Comment" >>$batchName/${batchName}_index.csv
echo Creating batch $batchName
for (( i=1; i<=$batch_amount; i++ ))
do
    p=`pwgen -cnsB 8 1`
    num=$(($d + $i))
    f=$batchName/${location}_key_${num}
    ssh-keygen -qa 100 -t ed25519 -N $p -C "${userlogin} key_$num" -f ./$f
    cp -r ./relay $batchName/relay_${location}_key_${num}
    export sshkey=${location}_key_${num}
    envsubst <$batchName/relay_${location}_key_${num}/conf/config.tpl >$batchName/relay_${location}_key_${num}/conf/config
    envsubst <$batchName/relay_${location}_key_${num}/tunnel.sh.tpl >$batchName/relay_${location}_key_${num}/tunnel.sh
    rm  $batchName/relay_${location}_key_${num}/*.tpl
    rm  $batchName/relay_${location}_key_${num}/conf/*.tpl
    echo "key_$num;$p;${location};;">>$batchName/${batchName}_index.csv
    echo `cat $f.pub`>>$batchName/${userlogin}
    cp $f $batchName/relay_${location}_key_${num}/conf/.
    echo generated $i $location key $num
    cd $batchName
    zip --exclude=*.DS_Store* -rmq  relay_${location}_key_${num}.zip relay_${location}_key_${num}
    rm -rf relay_${location}_key_${num}
    cd ..
done
mkdir $batchName/${batchName}_archive
cp $batchName/${batchName}_index.csv $batchName/${userlogin} $batchName/${batchName}_archive
mv $batchName/${location}_key* $batchName/${batchName}_archive
tar -czf  $batchName/${batchName}_archive.tgz $batchName/${batchName}_archive && rm -rf $batchName/${batchName}_archive
echo ""
echo "@nixos repo, do not forget to:"
echo "- copy (or add the content of)  ${userlogin} to org-spec/keys"
echo "- add ${userlogin}.enable = true; to the users.users object @org-spec/hosts/benucXXX.nix (port=${port_location})"
echo "- commit, push,pull and nixos-rebuild in the relays and benuc ${port_location}"