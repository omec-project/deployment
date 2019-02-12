#configuration
event_interval=1
mme_created_cmd="cat /tmp/deploy.log | grep \"mme: Creation complete \""
mme_configured_cmd="cat /tmp/deploy.log | grep \"Installation and configuration of hss\""
hss_created_cmd="cat /tmp/deploy.log | grep \"hss: Creation complete \""
hss_configured_cmd="cat /tmp/deploy.log | grep \"Installation and configuration of db\""
db_created_cmd="cat /tmp/deploy.log | grep \"db: Creation complete \""
db_configured_cmd="cat /tmp/deploy.log | grep \"Installation and configuration of spgwc\""
fpc_created_cmd="cat /tmp/deploy.log | grep \"fpc: Creation complete \""
fpc_configured_cmd="cat /tmp/deploy.log | grep \"Installation and configuration of DNS\""
spgwc_created_cmd="cat /tmp/deploy.log | grep \"spgwc: Creation complete \""
spgwc_configured_cmd="cat /tmp/deploy.log | grep \"Installation and configuration of FPC\""
spgwu_created_cmd="cat /tmp/deploy.log | grep \"spgwu: Creation complete \""
spgwu_configured_cmd="cat /tmp/deploy.log | grep \"spgwu : DPDK Binding for S1U and SGI Interface\""
status_lcmd="cat /tmp/deploy.log | grep TASK | tail -1 | cut -d '|' -f 2 | cut -d \"*\" -f1"
status_rcmd="cat /tmp/deploy.log | grep TASK | tail -1 | cut -d \"*\" -f1"
host_change_cmd="cat /tmp/deploy.log | grep \"PLAY RECAP\""
vms=['MME','HSS','DB','FPC','SPGWC','SPGWU']
