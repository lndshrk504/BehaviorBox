classdef BehaviorBoxSerialDebug
    methods (Static)
        function mode = normalizeMode(modeIn)
            mode = lower(strtrim(string(modeIn)));
            if ~any(mode == ["memory", "file", "failure"])
                mode = "memory";
            end
        end

        function tbl = emptyHistoryTable()
            tbl = table( ...
                'Size', [0 9], ...
                'VariableTypes', repmat({'string'}, 1, 9), ...
                'VariableNames', {'timestamp', 'direction', 'port', 'commandName', 'rawValue', 'eventType', 'status', 'matchKey', 'details'});
        end

        function ts = formatTimestamp(dt)
            if nargin < 1 || isempty(dt)
                dt = datetime('now', 'TimeZone', 'local');
            end
            if isempty(dt.TimeZone)
                dt.TimeZone = 'local';
            end
            dt.Format = "yyyy-MM-dd'T'HH:mm:ssXXX";
            ts = string(dt);
        end

        function debugDir = resolveDebugDir(sessionSaveFolder)
            sessionSaveFolder = string(sessionSaveFolder);
            if strlength(strtrim(sessionSaveFolder)) == 0
                debugDir = string(fullfile(pwd, 'Debug'));
            else
                debugDir = string(fullfile(char(sessionSaveFolder), 'Debug'));
            end
        end

        function [ok, debugDir, warnMsg] = ensureDebugDir(sessionSaveFolder)
            debugDir = BehaviorBoxSerialDebug.resolveDebugDir(sessionSaveFolder);
            warnMsg = "";
            try
                if ~isfolder(debugDir)
                    mkdir(debugDir);
                end
                ok = true;
            catch err
                ok = false;
                warnMsg = string(err.message);
            end
        end

        function [csvFile, stem] = continuousCsvPath(sessionSaveFolder, className)
            [ok, debugDir, warnMsg] = BehaviorBoxSerialDebug.ensureDebugDir(sessionSaveFolder);
            if ~ok
                error('BehaviorBoxSerialDebug:DebugDirCreateFailed', ...
                    'Could not create debug folder %s: %s', debugDir, warnMsg);
            end
            baseStem = "serial_txrx_" + string(className) + "_" + ...
                string(datetime('now', 'Format', 'yyyy_MM_dd-HH_mm_ss'));
            [stem, csvFile] = BehaviorBoxSerialDebug.uniqueStemWithExt_(debugDir, baseStem, ".csv");
        end

        function [jsonFile, csvFile, stem] = failureArtifactPaths(sessionSaveFolder, className)
            [ok, debugDir, warnMsg] = BehaviorBoxSerialDebug.ensureDebugDir(sessionSaveFolder);
            if ~ok
                error('BehaviorBoxSerialDebug:DebugDirCreateFailed', ...
                    'Could not create debug folder %s: %s', debugDir, warnMsg);
            end
            baseStem = "serial_failure_" + string(className) + "_" + ...
                string(datetime('now', 'Format', 'yyyy_MM_dd-HH_mm_ss'));
            [stem, jsonFile, csvFile] = BehaviorBoxSerialDebug.uniqueStemWithPair_(debugDir, baseStem, [".json", ".csv"]);
        end

        function row = makeRow(timestamp, direction, port, commandName, rawValue, eventType, status, matchKey, details)
            row = table( ...
                string(timestamp), ...
                string(direction), ...
                string(port), ...
                string(commandName), ...
                string(rawValue), ...
                string(eventType), ...
                string(status), ...
                string(matchKey), ...
                string(details), ...
                'VariableNames', {'timestamp', 'direction', 'port', 'commandName', 'rawValue', 'eventType', 'status', 'matchKey', 'details'});
        end

        function appendCsvRow(csvFile, row)
            needsHeader = ~isfile(csvFile);
            fid = fopen(char(csvFile), 'a');
            if fid < 0
                error('BehaviorBoxSerialDebug:OpenCsvFailed', ...
                    'Could not open %s for append.', csvFile);
            end
            cleaner = onCleanup(@() fclose(fid));
            if needsHeader
                fprintf(fid, '%s\n', BehaviorBoxSerialDebug.csvHeaderLine());
            end
            values = table2cell(row(1, :));
            fprintf(fid, '%s\n', BehaviorBoxSerialDebug.csvLine_(values));
        end

        function writeCsv(csvFile, rows)
            fid = fopen(char(csvFile), 'w');
            if fid < 0
                error('BehaviorBoxSerialDebug:OpenCsvFailed', ...
                    'Could not open %s for write.', csvFile);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid, '%s\n', BehaviorBoxSerialDebug.csvHeaderLine());
            for iRow = 1:height(rows)
                values = table2cell(rows(iRow, :));
                fprintf(fid, '%s\n', BehaviorBoxSerialDebug.csvLine_(values));
            end
        end

        function writeJson(jsonFile, metadata)
            fid = fopen(char(jsonFile), 'w');
            if fid < 0
                error('BehaviorBoxSerialDebug:OpenJsonFailed', ...
                    'Could not open %s for write.', jsonFile);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonencode(metadata));
        end

        function header = csvHeaderLine()
            header = 'timestamp,direction,port,commandName,rawValue,eventType,status,matchKey,details';
        end
    end

    methods (Static, Access = private)
        function [stem, filePath] = uniqueStemWithExt_(debugDir, baseStem, ext)
            stem = string(baseStem);
            suffix = 0;
            while true
                if suffix == 0
                    candidateStem = stem;
                else
                    candidateStem = stem + "_" + sprintf('%03d', suffix);
                end
                candidateFile = string(fullfile(char(debugDir), char(candidateStem + ext)));
                if ~isfile(candidateFile)
                    stem = candidateStem;
                    filePath = candidateFile;
                    return
                end
                suffix = suffix + 1;
            end
        end

        function [stem, firstFile, secondFile] = uniqueStemWithPair_(debugDir, baseStem, exts)
            stem = string(baseStem);
            suffix = 0;
            while true
                if suffix == 0
                    candidateStem = stem;
                else
                    candidateStem = stem + "_" + sprintf('%03d', suffix);
                end
                firstCandidate = string(fullfile(char(debugDir), char(candidateStem + exts(1))));
                secondCandidate = string(fullfile(char(debugDir), char(candidateStem + exts(2))));
                if ~isfile(firstCandidate) && ~isfile(secondCandidate)
                    stem = candidateStem;
                    firstFile = firstCandidate;
                    secondFile = secondCandidate;
                    return
                end
                suffix = suffix + 1;
            end
        end

        function line = csvLine_(values)
            parts = cellfun(@BehaviorBoxSerialDebug.csvEscape_, values, 'UniformOutput', false);
            line = strjoin(parts, ',');
        end

        function out = csvEscape_(value)
            if ismissing(value)
                txt = "";
            else
                txt = string(value);
            end
            txt = replace(txt, """", """""");
            out = char("""" + txt + """");
        end
    end
end
