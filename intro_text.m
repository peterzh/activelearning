text(begin_text(1),begin_text(2),['Welcome to our game! We are going to test your ability ' ...
    'to compare the contrast of two grating stimuli.'],'Color','white','FontSize',font_size)
text(button_text(1),button_text(2),'Press any key to continue.','Color','white','FontSize',font_size)
waitforbuttonpress;

figure(h);
imagesc( full_im, [-1 1]);
message = sprintf(['Focus on the + at the center of the screen and ' ...
    'push the left or right arrows to indicate which stimulus has higher contrast.']);
text(begin_text(1),begin_text(2),message,...
    'Color','white','FontSize',font_size)

text(button_text(1),button_text(2),['Press any key to start with some easy ' ...
    'example trials to practice before we begin.'],'Color','white','FontSize',font_size)
waitforbuttonpress;