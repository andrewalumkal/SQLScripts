create proc dbo.GenerateOptimalLogGrowthCommand
    @DesiredLogSizeMB   int           = 24576
   ,@DBName             nvarchar(200) = N'MyDB'
   ,@LogLogicalFileName nvarchar(200) = N'MyDB_log'
   ,@DetailedInfo       bit           = 0
as
begin
    declare @incrementsize int = 8192;
    declare @currentsize int = 0;
    declare @GrowthPct float = 1;
    declare @VLFSize float;
    declare @PrintCommand nvarchar(max);
    declare @Details nvarchar(max);

    while @DesiredLogSizeMB > @currentsize
    begin

        set @GrowthPct = (cast(@incrementsize as float) / cast(iif(@currentsize = 0, 1, @currentsize) as float))*100;

        while @GrowthPct < 12.5 --Need to be greater than 1/8th of log to avoid creating only 1 VLF for a growth cycle
        begin
            set @incrementsize = @incrementsize + 8192;
            set @GrowthPct = (cast(@incrementsize as float) / cast(iif(@currentsize = 0, 1, @currentsize) as float))*100;
        end;

        set @currentsize = @currentsize + @incrementsize;
        set @VLFSize = cast(@incrementsize as float) / 16;

        set @PrintCommand
            = N'ALTER DATABASE [' + @DBName + N'] MODIFY FILE ( NAME = N'''
              + @LogLogicalFileName + N''', size = '
              + cast(@currentsize as varchar(100)) + N'MB );';

        if @DetailedInfo = 1
        begin

            set @Details
                = N'Log Size:' + cast(@currentsize as varchar(100))
                  + N' | VLFSize: ' + cast(@VLFSize as varchar(100))
                  + N' | Increment:' + cast(@incrementsize as varchar(100))
                  + N' | Growth%:' + cast(@GrowthPct as varchar(100));

            print @Details;
        end;

        print @PrintCommand;
		print '';

    end;

end;


go
