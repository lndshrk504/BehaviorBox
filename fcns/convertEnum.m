%convert enum to integer
function [int_out] = convertEnum(enum_decision)
switch enum_decision
    case 'left correct'
        int_out = 1;
    case 'left correct OC' % When only correct mode is active, answered incorrectly but program stalled until correct response
        int_out = 1;
    case 'right correct'
        int_out = 2;
    case 'right correct OC' % When only correct mode is active, answered incorrectly but program stalled until correct response
        int_out = 2;
    case 'left wrong'
        int_out = 3;
    case 'right wrong'
        int_out = 4;
    case 'time out'
        int_out = 5;
    case 'time out - malingering'
        int_out = 6;
    case 'center poke'
        int_out = 6;
    otherwise
        int_out = -1;
end
end