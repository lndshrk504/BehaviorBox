classdef MockControl < matlab.mixin.SetGet
    properties
        Type char = 'uieditfield'
        Tag char = ''
        Value = []
        Items cell = {}
        String = ""
        Text = ""
        Enable logical = true
    end

    methods
        function this = MockControl(type, tag, value, items)
            if nargin >= 1
                this.Type = char(string(type));
            end
            if nargin >= 2
                this.Tag = char(string(tag));
            end
            if nargin >= 3
                this.Value = value;
                if isstring(value) || ischar(value)
                    this.String = char(string(value));
                    this.Text = char(string(value));
                end
            end
            if nargin >= 4
                this.Items = cellstr(string(items));
            end
        end
    end
end
