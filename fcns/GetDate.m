function DATE = GetDate
DATE = string();
DATE = string(datetime('now','TimeZone','local','Format','yy-MM-dd-HH:mm:ss'));
end