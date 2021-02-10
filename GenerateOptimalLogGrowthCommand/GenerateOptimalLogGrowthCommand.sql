---------------------SET VARIABLES------------------------
declare @DesiredLogSizeMB   int           = 200000
       ,@DBName             nvarchar(200) = N'MyDB'
       ,@LogLogicalFileName nvarchar(200) = N'MyDB_log'
       ,@DetailedInfo       bit           = 1;
----------------------------------------------------------


declare @incrementsize  int   = 8192
       ,@incrementCount int   = 0
       ,@currentsize    int   = 0
       ,@GrowthPct      float = 1
       ,@VLFSize        float
	   ,@TotalVLFs		int
       ,@PrintCommand   nvarchar(max)
       ,@Details        nvarchar(max);

while @DesiredLogSizeMB > @currentsize
begin

    set @GrowthPct = (cast(@incrementsize as float) / cast(iif(@currentsize = 0, 1, @currentsize) as float)) * 100;

    while @GrowthPct < 12.5 --Need to be greater than 1/8th of log to avoid creating only 1 VLF for a growth cycle
    begin
        set @incrementsize = @incrementsize + 8192;
        set @GrowthPct = (cast(@incrementsize as float) / cast(iif(@currentsize = 0, 1, @currentsize) as float)) * 100;
    end;

    set @currentsize = @currentsize + @incrementsize;
    set @VLFSize = cast(@incrementsize as float) / 16;
	set @incrementCount+=1;
	set @TotalVLFs = (@incrementCount*16) + 4 --Grows by 16 VLFs on every growth iteration based on this logic. 4 initial VLFs (approximate)

    set @PrintCommand
        = N'ALTER DATABASE [' + @DBName + N'] MODIFY FILE ( NAME = N'''
          + @LogLogicalFileName + N''', size = '
          + cast(@currentsize as varchar(100)) + N'MB );';

    if @DetailedInfo = 1
    begin

        set @Details
            = N'--Log Size:' + cast(@currentsize as varchar(100))
              + N' | VLFSizeThisIteration: ' + cast(@VLFSize as varchar(100)) + 'MB'
			  + N' | TotalVLFs: ' + cast(@TotalVLFs as varchar(100))
              + N' | Increment:' + cast(@incrementsize as varchar(100)) + 'MB'
              + N' | Growth%:' + cast(@GrowthPct as varchar(100));

        print @Details;
    end;

    print @PrintCommand;
    print '';

end;
