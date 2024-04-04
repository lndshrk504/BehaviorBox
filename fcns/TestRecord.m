function TestRecord
  % Create figure, axes and button
  f = figure;
  ax = axes(f, 'Position', [0.1 0.3 0.8 0.6]);
  btn = uicontrol(f, 'Style', 'pushbutton', 'String', 'Start', 'Position', [20 20 50 20]);

  % Create video input and video file writer
  imaqreset
  imaqmex('feature','-limitPhysicalMemoryUsage',false)
  vid = videoinput('winvideo', 1);
  vid.FramesPerTrigger = Inf;
  start(vid);
  vw = VideoWriter('video.avi');

  preview(vid)
  % Set button's callback
  btn.Callback = @buttonPushed;

  function buttonPushed(src, event)
    switch src.String
      case 'Start'
        % Change button string and start recording
        src.String = 'Stop';
        flushdata(vid)
        open(vw);
        while strcmp(src.String, 'Stop')
          frame = getdata(vid, 1);
          writeVideo(vw, frame);
          %imshow(frame, 'Parent', ax);
          drawnow;
        end
      case 'Stop'
        % Change button string and stop recording
        src.String = 'Start';
        close(vw);
    end
  end
end
