function SX = global_update(pth,t,iter,SX)
% For all job, sum over x
sx = 0;
for i=1:t
   load(pth{i},'x')
   sx = sx + x;               
   clear x
end
SX(iter) = sx;

fprintf('sx: %d \n',sx)

% Plot SX
figure(1);
semilogy(0:numel(SX) - 1,SX,'-'); drawnow    