declare @DBName nvarchar(200) = 'DBName';

drop table if exists #AllVLFs;
select db_name(database_id) as DBName
      ,file_id
      ,vlf_begin_offset
      ,vlf_size_mb
	  ,row_number() OVER(ORDER BY [file_id],vlf_begin_offset) AS VLF_OrdinalID
	  ,sum (vlf_size_mb) OVER (ORDER BY [file_id],vlf_begin_offset) AS RunningTlogSizeMBTotal
	  ,cast((cast(row_number() OVER(ORDER BY [file_id],vlf_begin_offset) as decimal(10,2)) /tc.TotalCount*100) as decimal(5,2)) as [RunningVLFCount%OfTotal]
	  ,cast(((sum (vlf_size_mb) OVER (ORDER BY [file_id],vlf_begin_offset)) / ts.TotalSizeMB ) * 100 as decimal(5,2)) as [RunningTlog%OfTotalSize]
      ,vlf_sequence_number
      ,vlf_active
      ,vlf_status
      ,vlf_parity
      ,vlf_first_lsn
      ,vlf_create_lsn 
into #AllVLFs
from  sys.dm_db_log_info(db_id(@DBName))
cross apply (select count(*) as TotalCount from sys.dm_db_log_info(database_id)) tc
cross apply (select sum(vlf_size_mb) as TotalSizeMB from sys.dm_db_log_info(database_id)) ts
order by [file_id],vlf_begin_offset asc
 
select * from  #AllVLFs as avf
order by avf.file_id asc,avf.vlf_begin_offset asc
 
--Get only active VLFs
select * from  #AllVLFs as avf
where avf.vlf_active=1
order by avf.file_id,avf.vlf_begin_offset asc
 
---Query from MSFT docs
Use [DBName]
go
;WITH cte_vlf AS (
SELECT ROW_NUMBER() OVER(ORDER BY vlf_begin_offset) AS vlfid, DB_NAME(database_id) AS [Database Name], vlf_sequence_number, vlf_active, vlf_begin_offset, vlf_size_mb
	FROM sys.dm_db_log_info(DEFAULT)),
cte_vlf_cnt AS (SELECT [Database Name], COUNT(vlf_sequence_number) AS vlf_count,
	(SELECT COUNT(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 0) AS vlf_count_inactive,
	(SELECT COUNT(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 1) AS vlf_count_active,
	(SELECT MIN(vlfid) FROM cte_vlf WHERE vlf_active = 1) AS ordinal_min_vlf_active,
	(SELECT MIN(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 1) AS min_vlf_active,
	(SELECT MAX(vlfid) FROM cte_vlf WHERE vlf_active = 1) AS ordinal_max_vlf_active,
	(SELECT MAX(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 1) AS max_vlf_active
	FROM cte_vlf
	GROUP BY [Database Name])
SELECT [Database Name], vlf_count, min_vlf_active, ordinal_min_vlf_active, max_vlf_active, ordinal_max_vlf_active,
((ordinal_min_vlf_active-1)*100.00/vlf_count) AS free_log_pct_before_active_log,
((ordinal_max_vlf_active-(ordinal_min_vlf_active-1))*100.00/vlf_count) AS active_log_pct,
((vlf_count-ordinal_max_vlf_active)*100.00/vlf_count) AS free_log_pct_after_active_log
FROM cte_vlf_cnt
GO
