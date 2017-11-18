function subject_update(t)
% Function that is executed by each individual worker on holly.
%
% The basic idea is to use the integer input (t) to load a path from a cell
% array stored in the same folder as the function. The path is then used to
% load a job-specific variable. In this case it is just a scalar value, but
% it can easily be changed to any kind of MATLAB object, e.g., a struct
% with many fields. Some processing is then done using this variable, and
% the variable is updated.
%
% Mikael Brudfors 2017-11-04
%==========================================================================

% Load variable using the cell array of paths pth_job_data
pth = '';
if isempty(pth)
   error('Absolute path (on Holly) to pth_job_data_array_h.mat needs to be set in subject_update!') 
end

load(pth,'pth_job_data_h');
pth = pth_job_data_h{t};
load(pth,'-mat','x');

% Print and increment x (the printout is stored in dir_logs)
fprintf('x=%d\n',x);
x = x + 1; % increment x

% Update x
save(pth,'x')
%==========================================================================