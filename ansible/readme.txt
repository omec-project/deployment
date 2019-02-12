# Installation of ansible packages 

https://docs.ansible.com/ansible/2.6/installation_guide/intro_installation.html
$ sudo apt-get update
$ sudo apt-get install software-properties-common
$ sudo apt-add-repository ppa:ansible/ansible
$ sudo apt-get update
$ sudo apt-get install ansible

# Execution of playbooks 

/usr/bin/ansible-playbook -i inventores/inventory site.yml  --private-key=/home/ubuntu/.ssh/id_rsa -u ubuntu -e githubuser="USERNAME" -e githubpassword="PASSWORD" 
