function [f] = testArduinoVolts(opt)
arguments
    opt.a = arduino()%the arduino
    opt.P1 = 'A5'
    opt.P2 = 'A4'
    opt.P3 = 'A3'
    opt.D1 = 'D2'
    opt.D2 = 'D3'
    opt.D3 = 'D4'
    opt.tLim = 30 %seconds
end
if isempty(opt.a)
    a = arduino();
else
    a = opt.a;
end
configurePin(a, "D2", "Pullup")
configurePin(a, "D3", "Pullup")
configurePin(a, "D4", "Pullup")
f = MakeAxis(m=3,n=1);
T = f.Children.findobj('Type', 'tiledlayout');
Ax = nexttile(T); hold(Ax,"on"); Ax5 = Ax;
Ax = nexttile(T); hold(Ax,"on"); Ax4 = Ax;
Ax = nexttile(T); hold(Ax,"on"); Ax3 = Ax;
V = 0;
V5 = 0;
V4 = 0;
V3 = 0;
p5 = plot(V, "-", "Color", "r",...
    "Parent",Ax5);
p4 = plot(V, "-", "Color", "r",...
    "Parent",Ax4);
p3 = plot(V, "-", "Color", "r",...
    "Parent",Ax3);
t1 = datetime("now");
while 1
    V5(end+1) = a.readDigitalPin(opt.D1); 
    V4(end+1) = a.readDigitalPin(opt.D2);
    V3(end+1) = a.readDigitalPin(opt.D3);
    p5.YData = V5;%(end+1) = a.readVoltage(opt.P1); 
    p4.YData = V4;%(end+1) = a.readVoltage(opt.P2);
    p3.YData = V3;%(end+1) = a.readVoltage(opt.P3);
    drawnow;
    pause(0.001)
end


end