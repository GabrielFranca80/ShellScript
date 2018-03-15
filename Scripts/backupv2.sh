#!/bin/bash
#====================================================================================================================
# script de backup desenvolvido por Gabriel Franca.																																		
#																													
# O backup será realizado em HD externo, ele irá criar uma pasta com a DATA dentro da unidade /media/smart/backup/      
# as pastas serão compactadas uma a uma e guardadas dentro da pasta DATA/compartilhamento.							
# No inicio do programa ele irá efetuar uma limpeza dos arquivos mais antigos.										
# Desenvolvido em 16/01/2017																						
# Versão 2.0    																									
#====================================================================================================================

######################### Variáveis ###########################

echo "Dados do Cliente irá aparecer no e-mail que será enviado"
NUMCLIENTE="01"
CLIENTE="CMC SOLUÇÕES"	

echo "Definir DATA e HORA do backup"
HORA=$(date +%H:%M)
DATA=$(date +%Y-%m-%d)

echo "Informações do HOST"
HOSTNAME=$(hostname)
IPHOST=$(/usr/sbin/ifconfig ens33 |grep inet |head -n1 |awk '{print $2 "/" $4}')
FILESYS=$(df -h|egrep -v '(tmpfs|udev)')
UPTIME=$(uptime -s)

echo "Onde os arquivos temporarios ficarão até mover para a unidade externa"
DIR_TEMP=/dados/tmp
ARQUIVO_TEMP1=/dados/tmp/LX-$DATA.tgz

echo "Local onde será guardado os bkps"
DISP_BACKUP="/media/smart/backup"

echo "arquivos a serem salvos no backup"
LX="/etc /root/gerencia /var/log /opt /root/bkpsmb"
DPTO="/dados/dpto"
SHARE="/dados/share"
USER="/dados/users"

echo "limpeza dos bkps antigos"
LOG="/var/log/backup/limpeza/$DATA.log"
DIAS=30

echo "log dos backups"
DIR_LOG=/var/log/backup
ARQUIVO_LOG=/var/log/backup/backup-$DATA
PASTAS_LOG=/var/log/backup/pastas
DPTO_LOG=/var/log/backup/dpto-$DATA
SHARE_LOG=/var/log/backup/share-$DATA
USER_LOG=/var/log/backup/user-$DATA
LX_LOG=/var/log/backup/lx-$DATA

################### Definindo dia da semana #################
case $(date |awk '{print $1}') in
	Dom) 
		DIACASE=0
		;;		
	Seg) 
		DIACASE=1
		;;
	Ter)
		DIACASE=2
		;;
	Qua)
		DIACASE=3
		;;
	Qui)
		DIACASE=4
		;;
	Sex)
		DIACASE=5
		;;
	Sab) 
		DIACASE=6
		;;	
esac

######################### Funções ###########################

## Função de limpeza vai deletar os arquivos com base na quantidade de dias selecionado para retenção. ##

function LIMPABACKUP () {
	
echo "-- LIMPEZA INICIADA EM $(date +%d/%m/%Y) AS $(date +%H:%M:%S) -- " >> $LOG
#Remove os arquivos antigos baseados na DATA em que foram criados.
find "$DISP_BACKUP" -type f -ctime "+$DIAS" | sed 's/^/"/g ; s/$/"/g' | xargs rm -rf
##Remove os arquivos de logs antigos baseados na DATA em que foram criados.
find "$DIR_LOG" -type f -ctime "+$DIAS" | sed 's/^/"/g ; s/$/"/g' | xargs rm -rf

#Controle do tamanho do arquivo de log
TAM_LOG=$(du $LOG | awk '{print $1}')

#Definido que o arquivo de log deve ser menor do que 200 KB
if [ $TAM_LOG -ge 200 ]; then
   rm $LOG
fi
echo "-- LIMPEZA FINALIZADA EM $(date +%d/%m/%Y) AS $(date +%H:%M:%S) -- " >> $LOG
}

echo "Função do backup da pasta Home"

## Função para backup da pasta dpto nessa pasta os usuários não podem criar e deletar qualquer tipo de Pasta ##

function BACKUPDPTO () {
		
## Inicio do Backup individual das pastas dentro do FIPECQ ## 
OLDIFS=$IFS
IFS=$'\n'
find $DPTO -maxdepth 1 -type d |awk -F / {'print $NF'} | sed "1d" | sed 's/ /\\ /g' > /tmp/DPTOTMP.txt

while read I; do
								
echo "Gerando arquivo compactado"
if [ "$DIACASE" -eq "0" ]; then
	tar -czvf $DIR_TEMP/"$I-$DATA.tgz" $DPTO/"$I" > $PASTAS_LOG/"$I-$DATA.txt"
	RETN1=$?
else
	find $DPTO/"$I" -mtime -$DIACASE -type f -print | tar -czvf $DIR_TEMP/"$I-$DATA.tgz" --exclude-from=/root/gerencia/scripts/bkpexclude -T - > $PASTAS_LOG/"$I-$DATA.txt" 
	RETN1=$?
fi

echo "Movendo o Backup para o SMART"
mv $DIR_TEMP/"$I-$DATA.tgz" $DISP_BACKUP/$DATA/dpto/
RETN2=$?
                                
echo "testando $I"
tar -tzf $DISP_BACKUP/$DATA/dpto/"$I-$DATA.tgz" > /dev/null 2>&1
RETN3=$?
                                
echo "Validando e escrevendo no log os retornos dos comandos"
                                	
if [ "$RETN1" -eq "0" ]; then
	GER=ok	
else
	GER=Fail
fi
                                        
if [ "$RETN2" -eq "0" ]; then
	MOV=ok	
else
	MOV=Fail	
fi

if [ "$RETN3" -eq "0" ]; then
	DESC=ok	
else
	DESC=Fail
fi

echo "==================================================================" >  $DPTO_LOG
echo "Departamental" >> $DPTO_LOG								
echo "==================================================================" >> $DPTO_LOG								
echo -e "Pasta	| Gerado | Movido | Descompactado" >> $DPTO_LOG
echo "==================================================================" >> $DPTO_LOG

if [ "$GER" == "ok" ] && [ "$MOV" == "ok" ] && [ "$DESC" == "ok" ]; then
	echo "Gerado com sucesso"
else
	echo -e "$I | $GER | $MOV | $DESC" >> $DPTO_LOG
	echo "==================================================================" >> $DPTO_LOG
fi

done </tmp/DPTOTMP.txt
                                
IFS=$OLDIFS                   
}

function BACKUPSHARE () {
		
## Inicio do Backup individual das pastas dentro do SHARE ## 
OLDIFS=$IFS
##IFS="^M"
IFS=$'\n'
find $SHARE -maxdepth 1 -type d |awk -F / {'print $NF'} | sed "1d" | sed 's/ /\\ /g' > /tmp/SHARETMP.txt

while read I; do
								
echo "Gerando arquivo compactado"
if [ "$DIACASE" -eq "0" ]; then
	tar -czvf $DIR_TEMP/"$I-$DATA.tgz" $SHARE/"$I" > $PASTAS_LOG/"$I-$DATA.txt"
	RETN1=$?
else
	find $SHARE/"$I" -mtime -$DIACASE -type f -print | tar -czvf $DIR_TEMP/"$I-$DATA.tgz" --exclude-from=/root/gerencia/scripts/bkpexclude -T - > $PASTAS_LOG/"$I-$DATA.txt" 
	RETN1=$?
fi

echo "Movendo o Backup para o SMART"
mv $DIR_TEMP/"$I-$DATA.tgz" $DISP_BACKUP/$DATA/share/
RETN2=$?
                                
echo "testando $I"
tar -tzf $DISP_BACKUP/$DATA/share/"$I-$DATA.tgz" > /dev/null 2>&1
RETN3=$?
                                
echo "Validando e escrevendo no log os retornos dos comandos"
                                	
if [ "$RETN1" -eq "0" ]; then
	GER=ok	
else
	GER=Fail
fi
                                        
if [ "$RETN2" -eq "0" ]; then
	MOV=ok	
else
	MOV=Fail	
fi

if [ "$RETN3" -eq "0" ]; then
	DESC=ok	
else
	DESC=Fail
fi

echo "==================================================================" >  $SHARE_LOG
echo "Pasta Compartilhada" >> $SHARE_LOG								
echo "==================================================================" >> $SHARE_LOG								
echo -e "Pasta	| Gerado | Movido | Descompactado" >> $SHARE_LOG
echo "==================================================================" >> $SHARE_LOG

if [ "$GER" == "ok" ] && [ "$MOV" == "ok" ] && [ "$DESC" == "ok" ]; then
	echo "Gerado com sucesso"
else
	echo -e "$I | $GER | $MOV | $DESC" >> $SHARE_LOG
	echo "==================================================================" >> $SHARE_LOG
fi

done </tmp/SHARETMP.txt
                                
echo "Criando os bkp dos arquivos soltos na pasta raiz do share"

if [ "$DIACASE" -eq "0" ]; then
	find $SHARE -maxdepth 1 -type f |tar -czvf $DIR_TEMP/"ARQUIVOS-$DATA.tgz" -T - > $PASTAS_LOG/"ARQUIVOS-$DATA.txt"
	RETN1=$?
else
	find $SHARE -maxdepth 1 -type f -mtime -$DIACASE | tar -czvf $DIR_TEMP/"ARQUIVOS-$DATA.tgz" -T - > $PASTAS_LOG/"ARQUIVOS-$DATA.txt"
	RETN1=$?
fi	

echo "Movendo o Backup para o SMART"
mv $DIR_TEMP/"ARQUIVOS-$DATA.tgz" $DISP_BACKUP/$DATA/share/
RETN2=$?
                                
echo "testando Arquivos.tgz"
tar -tzf $DISP_BACKUP/$DATA/share/"ARQUIVOS-$DATA.tgz" > /dev/null 2>&1
RETN3=$?
                                
echo "Validando e escrevendo no log os retornos dos comandos"
                                	
if [ "$RETN1" -eq "0" ]; then
	GER=ok	
else
	GER=Fail
fi
                                        
if [ "$RETN2" -eq "0" ]; then
	MOV=ok	
else
	MOV=Fail	
fi

if [ "$RETN3" -eq "0" ]; then
	DESC=ok	
else
	DESC=Fail
fi   

if [ "$GER" == "ok" ] && [ "$MOV" == "ok" ] && [ "$DESC" == "ok" ]; then
	echo "Gerado com sucesso"
else
	echo -e "$I | $GER | $MOV | $DESC" >> $SHARE_LOG
	echo "==================================================================" >> $SHARE_LOG
fi                             
IFS=$OLDIFS                   
}

function BACKUPUSER () {
		
## Inicio do Backup individual das pastas dentro do FIPECQ ## 
OLDIFS=$IFS
IFS=$'\n'
find $USER -maxdepth 1 -type d |awk -F / {'print $NF'} | sed "1d" | sed 's/ /\\ /g' > /tmp/USERTMP.txt

while read I; do
								
echo "Gerando arquivo compactado"
if [ "$DIACASE" -eq "0" ]; then
	tar -czvf $DIR_TEMP/"$I-$DATA.tgz" $USER/"$I" > $PASTAS_LOG/"$I-$DATA.txt"
	RETN1=$?
else
	find $USER/"$I" -mtime -$DIACASE -type f -print | tar -czvf $DIR_TEMP/"$I-$DATA.tgz" --exclude-from=/root/gerencia/scripts/bkpexclude -T - > $PASTAS_LOG/"$I-$DATA.txt" 
	RETN1=$?
fi

echo "Movendo o Backup para o SMART"
mv $DIR_TEMP/"$I-$DATA.tgz" $DISP_BACKUP/$DATA/user/
RETN2=$?
                                
echo "testando $I"
tar -tzf $DISP_BACKUP/$DATA/user/"$I-$DATA.tgz" > /dev/null 2>&1
RETN3=$?
                                
echo "Validando e escrevendo no log os retornos dos comandos"
                                	
if [ "$RETN1" -eq "0" ]; then
	GER=ok	
else
	GER=Fail
fi
                                        
if [ "$RETN2" -eq "0" ]; then
	MOV=ok	
else
	MOV=Fail	
fi

if [ "$RETN3" -eq "0" ]; then
	DESC=ok	
else
	DESC=Fail
fi

echo "==================================================================" >  $USER_LOG
echo "Usuários" >> $USER_LOG								
echo "==================================================================" >> $USER_LOG								
echo -e "Pasta	| Gerado | Movido | Descompactado" >> $USER_LOG
echo "==================================================================" >> $USER_LOG

if [ "$GER" == "ok" ] && [ "$MOV" == "ok" ] && [ "$DESC" == "ok" ]; then
	echo "Gerado com sucesso"
else
	echo -e "$I | $GER | $MOV | $DESC" >> $USER_LOG
	echo "==================================================================" >> $USER_LOG
fi

done </tmp/USERTMP.txt
                                
IFS=$OLDIFS                   
}
## Função para realizar o backup das pastas de configuração do servidor linux definidos lá no inicio do programa ##

function BACKUPLX () {
				
echo "Gerando o backup das configurações do linux"
tar -czvf $ARQUIVO_TEMP1 $LX
RETN1=$?
                
echo "Movendo o Backup para o SMART"
mv $ARQUIVO_TEMP1 $DISP_BACKUP/$DATA/lx/
RETN2=$?

tar -tzf $DISP_BACKUP/$DATA/lx/LX-$DATA.tgz > /dev/null 2>&1
RETN3=$?
echo "Validando e escrevendo no log os retornos dos comandos"
                                	
if [ "$RETN1" -eq "0" ]; then
	GER=ok	
else
	GER=Fail
fi
                                        
if [ "$RETN2" -eq "0" ]; then
	MOV=ok	
else
	MOV=Fail	
fi

if [ "$RETN3" -eq "0" ]; then
	DESC=ok	
else
	DESC=Fail
fi
echo "==================================================================" > $LX_LOG
echo "Configurações Linux" >> $LX_LOG
echo "==================================================================" >> $LX_LOG
echo "==================================================================" >> $LX_LOG								
echo -e "Pasta	| Gerado | Movido | Descompactado" >> $LX_LOG
echo "==================================================================" >> $LX_LOG
echo "==================================================================" >> $LX_LOG

if [ "$GER" == "ok" ] && [ "$MOV" == "ok" ] && [ "$DESC" == "ok" ]; then
	echo "Gerado com sucesso"
else
	echo -e "$I | $GER | $MOV | $DESC" >> $LX_LOG
	echo "==================================================================" >> $LX_LOG
fi
}

######################### Montagem do HD externo e inicio do Backup ###########################  
# Desmontando o hd externo caso ele esteja montado
umount /media/smart
sleep 2

## Montando o SMART e validando a montagem coloquei um teste para caso o hd externo não esteja presente o sistema envie um email com a mensagem.
## Veja que estou usando um LABEL NO HD EXTERNO faço isso para evitar que outro dispositivo use o caminho e acabe dando erro.   

if ! mount LABEL=hdbkp /media/smart; then
	
FILESYS=$(df -h|egrep -v '(tmpfs|udev)')
echo "Subject: $NUMCLIENTE - Erro na unidade de Backup $CLIENTE\n\n" > $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "Relatório da Máquina: $HOSTNAME" >> $ARQUIVO_LOG
echo "Ip do Servidor: $IPHOST" >> $ARQUIVO_LOG
echo "Data/Hora: $(date)" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG 
echo "Máquina Ativa desde: $UPTIME" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "hd externo com erro, backup nao realizado !!!!!" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "Partições:" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "$FILESYS" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
ssmtp -C /root/gerencia/scripts/ssmtp.conf suporte@cmcsolucoes.com.br < $ARQUIVO_LOG
else

######################### Criar pastas do backup ##################################
mkdir -p /var/log/backup/limpeza
mkdir -p /var/log/backup/pastas
mkdir -p $DISP_BACKUP/$DATA/user
mkdir -p $DISP_BACKUP/$DATA/dpto
mkdir -p $DISP_BACKUP/$DATA/share
mkdir -p $DISP_BACKUP/$DATA/lx

######################### Executar as funções de backup ###########################

LIMPABACKUP
sleep 5
BACKUPDPTO
sleep 5
BACKUPSHARE
sleep 5
BACKUPUSER
sleep 5
BACKUPLX
sleep 5
######################## Relatório do Backup enviado por e-mail #####################

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
FILESYS=$(df -h|egrep -v '(tmpfs|udev)')
echo -e "Subject: $NUMCLIENTE - Backup Diario $CLIENTE\n\n" > $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "Relatório da Máquina: $HOSTNAME" >> $ARQUIVO_LOG
echo "Ip do Servidor: $IPHOST" >> $ARQUIVO_LOG
echo "Data/Hora: $(date)" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG 
echo "Máquina Ativa desde: $UPTIME" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "Partições:" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "$FILESYS" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "arquivos com problemas" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
cat $DPTO_LOG >> $ARQUIVO_LOG
cat $SHARE_LOG >> $ARQUIVO_LOG
cat $USER_LOG >> $ARQUIVO_LOG
cat $LX_LOG >> $ARQUIVO_LOG
echo "arquivos dentro da pasta DPTO" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "$(du -hs /media/smart/backup/$DATA/dpto/* | sort -n)" >> $ARQUIVO_LOG
sed -i "s/\/media\/smart\/backup\/$DATA\/dpto\///g" $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "arquivos dentro da pasta COMPARTILHADA" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "$(du -hs /media/smart/backup/$DATA/share/* | sort -n)" >> $ARQUIVO_LOG
sed -i "s/\/media\/smart\/backup\/$DATA\/share\///g" $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "arquivos dentro da pasta USUÁRIOS" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "$(du -hs /media/smart/backup/$DATA/user/* | sort -n)" >> $ARQUIVO_LOG
sed -i "s/\/media\/smart\/backup\/$DATA\/user\///g" $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "backup Linux" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "$(du -hs /media/smart/backup/$DATA/lx/* | sort -n)" >> $ARQUIVO_LOG
sed -i "s/\/media\/smart\/backup\/$DATA\/lx\///g" $ARQUIVO_LOG
echo "" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "==================================================================" >> $ARQUIVO_LOG
echo "Inicio do backup as $HORA" >> $ARQUIVO_LOG
HORA1=`date +%H:%M`
echo "Fim do backup as $HORA1" >> $ARQUIVO_LOG
echo "Enviando email"
ssmtp -C /root/gerencia/scripts/ssmtp.conf suporte@cmcsolucoes.com.br < $ARQUIVO_LOG
fi
sync
sleep 5
sync
######################### Desmontar as unidades externas ###########################    
echo "Desmontando o SMART"
umount /media/smart
