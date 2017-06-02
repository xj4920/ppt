



library(RODBC)
library(WindR)
library(sqldf)
library(knitr)
library(xtable)

rm(list = ls())
w.start(showmenu=F)


setwd("E:\\DP\\DpRepo\\python\\dputil\\src")

# Connect to DB
jydb_allConnect  <- odbcConnect('252',uid='dpadmin',pwd='dpadmin')

# Get portid list
sql.getPortID <- paste("select distinct RTRIM(PortID) as portid, RTRIM(PortSName) as portsname from jydb_all.dbo.dpProd;")


Prod.PortID <- sqlQuery(jydb_allConnect , as.is=FALSE, sql.getPortID)

# Get position
Prod.pos <- data.frame()
for (i in 1: dim(Prod.PortID[1])[1])
{
  sql.positionstk <- paste("select date, holdingamount, rtrim(SecurityID) as code, rtrim(portid) as portid, CostMarketValue, CurrentMarketValue,  PnL from jydb_all.dbo.dpPortDetails pos where
                           Date = (select MAX(Date) from jydb_all.dbo.dpPortDetails where PortID ='", Prod.PortID[i,1] ,"') and PortID = '", Prod.PortID[i,1] ,"';", sep = '')
  Prod.pos <- rbind(Prod.pos, sqlQuery(jydb_allConnect , sql.positionstk))
}



# Format data
Prod.pos$code = sprintf("%06d", Prod.pos$code)


Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('5','6')] <- paste(Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('5','6')], ".SH", sep='')
Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('0','3')] <- paste(Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('0','3')], ".SZ", sep='')
Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('1')] <- paste(Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('1')], ".OF", sep='')
Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('I')] <- paste(Prod.pos$code[substr(Prod.pos$code,start=1,stop=1)%in%c('I')], ".CFE", sep='')


# Prod.pos[, 5] <- gsub(',', '', Prod.pos[, 5])
# Prod.pos[5] <- lapply(Prod.pos[5], as.numeric)
# Prod.pos[, 7] <- gsub(',', '', Prod.pos[, 7])
#Prod.pos[7] <- lapply(Prod.pos[7], as.numeric)
#Prod.pos[, 9] <- gsub(',', '', Prod.pos[, 9])
#Prod.pos[9] <- lapply(Prod.pos[9], as.numeric)

                      
# Prod.pos <- rbind(Prod.pos, data.frame(date='2015-09-16', holdingamount=100,  code='000818.SZ', portid='HB0A01', CostMarketValue=10000, PctMVofCost=0.02 , CurrentMarketValue='10000', PctMVofCurrent=0.05, PnL=500))

# Get stock status
wd.status <-w.wss(unique(Prod.pos[, 3]),'trade_status, sec_type, sec_name', paste('tradeDate=', Sys.Date()))$Data
nontradinglist <- wd.status[!wd.status$TRADE_STATUS=="����",]
nontradinglist <- nontradinglist[nontradinglist$SEC_TYPE=="��ͨ��",]
Prod.suspended <- merge(Prod.pos, nontradinglist, by.x='code', by.y='CODE')


TradeResume <- w.wset('TradeResume', paste('startdate=', Sys.Date(), ';', 'enddate=', Sys.Date()))$Data

TradeResume <- sqldf("select wind_code, sec_name from 'TradeResume'")

Resume <- merge(data.frame(code=unique(Prod.pos[, 3])), TradeResume, by.x = 'code', by.y = 'wind_code')

Resume <- merge(Prod.pos, Resume, by.x='code', by.y='code')

Resume <- sqldf("select (Case when portid = 'CM1B01' then '����һ��' 
                              when portid = 'CS2B02' then '��������' 
                              when portid = 'CM1C01' then '�Ƚ�һ��' 
                              when portid = 'HB0A01' then '����һ��' 
                              when portid = 'PH0A02' then '����һ��' 
                              when portid = 'CS9Z01' then '������Ӫ' end) as ��Ʒ���,  
                        code as '��Ʊ����', 
                        sec_name as '��Ʊ����',
                        holdingamount as '�ֲ���',
                        CurrentMarketValue as 'ͣ����ֵ' from Resume")

# Resume <- merge(rbind(data.frame(code=Prod.pos[, 3]), data.frame(code='000818.SZ')), TradeResume$Data, by.x = 'code', by.y = 'wind_code')


# Calculate marketvalue which is suspended
mv <- sqldf("select portid, sum(CurrentMarketValue) as MV from 'Prod.suspended' group by portid order by portid")
mv <- merge(mv,  Prod.PortID, by.x='portid', by.y='portid')
mv <- sqldf("select portsname as '�������', mv as 'ͣ����ֵ' from mv")
suspendMV <- sqldf("select code as '��Ʊ����', SEC_NAME as '��Ʊ����',
                           sum(CurrentMarketValue) as 'ͣ����ֵ',
                           sum(CASE when portid = 'CM1B01' then CurrentMarketValue else 0 end) as '����һ��',
                           sum(CASE when portid = 'CS2B02' then CurrentMarketValue else 0 end) as '��������',
                           sum(CASE when portid = 'CM1C01' then CurrentMarketValue else 0 end) as '�Ƚ�һ��',
                           sum(CASE when portid = 'HB0A01' then CurrentMarketValue else 0 end) as '����һ��',
                           sum(CASE when portid = 'PH0A02' then CurrentMarketValue else 0 end) as '����һ��',
                           sum(CASE when portid = 'CS9Z01' then CurrentMarketValue else 0 end) as '������Ӫ'
                    from 'Prod.suspended' group by code" )



suspendMV <- suspendMV[order(-rank(suspendMV$ͣ����ֵ)), ]

# sqldf("select code + ',' +  date from 'Prod.suspended'")

write.csv(Prod.suspended, file= paste("./suspended_", format(Sys.time(), '%Y%m%d'), '.csv', sep = ''))



file.remove('mail.html')

write("������Ϣ", file='mail.html', append = TRUE)
write(print.xtable(xtable(Resume), type="html"), file='mail.html', append = TRUE)


write("����Ʒ��ͣ����ֵ", file='mail.html', append = TRUE)
write(print.xtable(xtable(mv), type="html"), file='mail.html', append = TRUE)


write("ÿֻͣ�ƹ�Ʊ�ڸ���Ʒ�����", file='mail.html', append = TRUE)
write(print.xtable(xtable(suspendMV), type="html"), file='mail.html', append = TRUE)




# Close DB
odbcClose(jydb_allConnect)


# knit2html('./suspendMV.rmd')


