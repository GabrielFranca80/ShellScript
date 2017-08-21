#!/bin/bash
# script de backup desenvolvido por Gabriel Franca.
# O backup será realizado em HD externo, ele irá criar uma pasta com a data dentro da unidade /media/smart/backup/	
# as pastas serão compactadas uma a uma e guardadas dentro da pasta data/compartilhamento.
# No inicio do programa ele irá efetuar uma limpeza dos arquivos mais antigos.
# Desenvolvido em 15/08/2017
# Versão 2.0	

######################### Variáveis ###########################
echo "Definir data e hora do backup"

hora=`date +%H:%M`
data=`date +%Y-%m-%d`

echo "Onde os arquivos temporarios ficarão até mover para a unidade externa"

dir_temp=/tmp

echo "Local onde será guardado os bkps"

disp_backup="/media/smart/backup"

echo "arquivos a serem salvos no backup"

lx="/etc /home /root/gerencia /var/logs /var/www /var/named /opt"
user="/dados/users"
share="/dados/share/"
dpto="/dados/dpto"

echo "log dos backups"
dir_log=/var/log/backup

######################### Funções ###########################

## Função de limpeza vai deletar os arquivos com base na quantidade de dias selecionado para retenção. ##
	
function LIMPABACKUP () {
				#Diretorio da Limpeza
						diretorio_backup="/media/smart/backup"

				#Arquivo de Log
						log="/var/log/backup/limpeza/data.log";

				#Define a quantidade de dias a serem mantidos.
						dias="10";

				#Remove os arquivos antigos baseados na data em que foram movidos para lixeira
						find "$diretorio_lixeira" -type f -ctime "+$dias" | sed 's/^/"/g ; s/$/"/g' | xargs rm -rf

				#Controle do tamanho do arquivo de log
						tam_log=`du $log | awk '{print $1}'`

				#Definido que o arquivo de log deve ser menor do que 200 KB
						if [ $tam_log -ge 200 ]; then
							rm $log
						fi
						echo "-- LIMPEZA REALIZADA EM `date +%d/%m/%Y` AS `date +%H:%M:%S` -- " >> $log
				}

echo "Função do backup da pasta Home"

## Função para backup da pasta dos usuários (pasta individual) ##

function BACKUPHOME () {

                for home in $user/*; do

                        LOCAL=`echo $home |awk -F / {'print $NF'}`

                        tar -czvf $dir_temp/$LOCAL-$data.tgz $user/$LOCAL > $dir_log/$LOCAL-$data
                        echo "Movendo o Backup para o SMART"
						mv $dir_temp/$LOCAL-$data.tgz $disp_backup/$data/usuarios/
                done;

                }
                
echo " Função do backup da pasta Dpto"

## Função para backup da pasta departamental ##

function BACKUPDPTO () {

            	for dpt in $dpto/*; do

                        LOCAL=`echo $dpt |awk -F / {'print $NF'}`

                        tar -czvf $dir_temp/$LOCAL-$data.tgz $dpto/$LOCAL > $dir_log/$LOCAL-$data
                		echo "Movendo o Backup para o SMART"
						mv $dir_temp/$LOCAL-$data.tgz $disp_backup/$data/dpto/
                done;

                } 

## Função para backup da pasta compartilhada nessa pasta os usuários podem criar e deletar qualquer tipo de arquivo ##

function BACKUPSHARE () {
	## Efetuando Backup dos arquivos soltos dentro da pasta Share ##
	ARQ=`find $share -maxdepth 1 -type f | awk -F / {'print $NF'}`
						cd /dados/share/
						tar -czvf $dir_temp/sharearq-$data.tgz $ARQ 
						mv $dir_temp/sharearq-$data.tgz $disp_backup/$data/share/
	## Fim da parte que realiza backup dos arquivos Soltos na pasta Share ##
						
	## Inicio do Backup individual das pastas dentro do share ## 
	IFS="^M"
	find $share -maxdepth 1 -type d |awk -F / {'print $NF'} | sed "1d" | sed 's/ /\\ /g' > /tmp/ARQ.txt
						
				while read I; do 
						tar -czvf $dir_temp/${I}-$data.tgz $share/${I}
                   		echo "Movendo o Backup para o SMART"
						mv $dir_temp/${I}-$data.tgz $disp_backup/$data/share/;
				done </tmp/ARQ.txt
				reset		
	## Fim do backup do Share ##			
	            }
## Função para realizar o backup das pastas de configuração do servidor linux definidos lá no inicio do programa ##
	                
function BACKUPLX () {

                tar -czvf $arquivo_temp1 $lx --exclude-from=/root/gerencia/scripts/bkpexclude > $arquivo_log1
                }                   
                
                                           
######################### Montagem do HD externo e inicio do Backup ###########################  

# Desmontando o hd externo caso ele esteja montado

umount /media/smart
sleep 2

## mount /dev/sdb1 /media/smart
## Montando o SMART e validando a montagem coloquei um teste para caso o hd externo não esteja presente o sistema envie um email com a mensagem.
## Veja que estou usando um LABEL NO HD EXTERNO faço isso para evitar que outro dispositivo use o caminho e acabe dando erro. 	
if ! mount LABEL=hdbkp /media/smart; then
   echo "Subject:07 - Erro na unidade de Backup" > $arquivo_log
   echo "hd externo com erro backup nao realizado !!!!!" >> $arquivo_log
        SHELL=/bin/sh
        PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
        ssmtp -C /root/gerencia/scripts/ssmtp.conf suporte@cmcsolucoes.com.br < $arquivo_log
else

######################### Criar pastas do backup ###########################
	mkdir -p /var/log/backup/limpeza
	mkdir -p $disp_backup/$data/usuarios
	mkdir -p $disp_backup/$data/dpto
	mkdir -p $disp_backup/$data/share
   
######################### Executar as funções de backup ###########################

LIMPABACKUP
sleep 5
BACKUPHOME
sleep 5
BACKUPDPTO 
sleep 5
BACKUPSHARE
sleep 5

######################### Relatório do Backup enviado por e-mail ###########################
        
#Testar arquivo gzip

#gzip -tv backup.tar.gz 

#backup.tar.gz:   OK asdf



######################### Teste de descompressão dos arquivos guardados no HD externo ###########################        



######################### Ver espaço em disco e envio do email ###########################	
    	
#   	 echo -e "`df -h`" >> $arquivo_log
#        echo "" >> $arquivo_log
#        echo "-----------------------------------------------------------" >> $arquivo_log
#		 echo "-----------------------------------------------------------" >> $arquivo_log
#        echo "Teste do HD" >> $arquivo_log
#	echo "Disco Principal" >> $arquivo_log
#	smartctl -H /dev/sda >> $arquivo_log
#	echo "-----------------------------------------------------------" >> $arquivo_log
#        echo "" >> $arquivo_log
#        echo "Inicio do backup as $hora" >> $arquivo_log
#	hora1=`date +%H:%M`
#        echo "Fim do backup as $hora1" >> $arquivo_log
#        echo "Enviando email"
#        ssmtp -C /root/gerencia/scripts/ssmtp.conf bkpgrp@cmcsolucoes.com.br < $arquivo_log
fi

sync 
sleep 20
sync
######################### Desmontar as unidades externas ###########################	

echo "Desmontando o SMART"
umount /media/smart

######################### Fim do backup e tempo de duração ###########################	
echo 
hora=`date +%H:%M`
echo "Fim do backup as $hora"