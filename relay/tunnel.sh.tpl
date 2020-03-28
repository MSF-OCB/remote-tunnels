mkdir -p ~/.ssh
cp conf/*  ~/.ssh/.
echo "Connecting to project ${location}..."
echo "You may be asked twice for the password - this is OK"
echo "After the second password nothing will happen - this is OK"
echo "You will be tunnelled until you close this window"
echo ""
ssh -N $location