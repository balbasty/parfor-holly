%==========================================================================
% This code is a demo of how MATLAB can be enabled to interface with the
% FIL cluster holly, i.e., it emulates parfor, but on holly instead of the
% local machine. In pseudocode this process can be described by:
%
% for iter=1:niter
%     executes t jobs on holly
%
%     when holly finished
%         do something with the results from the holly execution
%     end
% end
%
% What the code does: The code runs t jobs in parallel on holly, for a set
% number of iterations. Each job loads a job-specific variable (x) from
% disk, prints the value of this variable, increments it by one, and then
% saves the updated variable. When all variables have been updated, they
% are summed and then the sum is plotted.
%
% Prerequisites: 
% -A machine running a Unix based OS (e.g. CentOS, OSX, Ubuntu) (TODO: should work on Windows by interfacing with, e.g., Git BASH) 
% -sshpass installed (on CentOS do 'yum install sshpass') 
% -An account on holly 
% -A folder on the local computer (dir_root_l) that maps to a folder on holly (dir_root_h)
%
% OBS:
% The MATLAB function that will run on holly (in this script called foo)
% requires a hardcoded path.
%
% Finally: Any feedback and/or improvements are greatly appreciated! Please
% just do a pull request to the GitHub repo where you found this code.
% Thank you :)
%
% Mikael Brudfors
% 2017-11-04
%==========================================================================

%==========================================================================
%% Initialise

close all; clear; clc;

%--------------------------------------------------------------------------
% Read path to required directories from .txt file
% The file should contain, on each new line;
% dir_root_h - The folder on holly where logs, scripts and data will be stored
% dir_root_l - The location on the local machine to which dir_root_h is mapped (OBS: could have the same name as dir_root_h)
% dir_pwd_h  - The location of this code on holle (remember, now you are on your local machine)
[dir_root_h,dir_root_l,dir_pwd_h] = read_directory_details('directory_details.txt');

dir_matlab_h = '/share/apps/MATLAB/R2016a/bin/matlab'; % The path to MATLAB on holly

%--------------------------------------------------------------------------
% Read Holly username and password from .txt file
% The file should contain username and password on separate lines
[username,password] = read_user_details('user_details.txt');

%--------------------------------------------------------------------------
% Cluster parameters
RAM = 2;  % RAM to allocate for each job (if this value is to small, expect hard to trace runtime errors...)
t   = 10; % Number of jobs to run on holly 

%--------------------------------------------------------------------------
% Path to directories on local
dir_job_data_l = fullfile(dir_root_l,'data');    % data on local
dir_logs_l     = fullfile(dir_root_l,'logs');    % logs on local
dir_scripts_l  = fullfile(dir_root_l,'scripts'); % scripts on local

% Make folders on local
if exist(dir_job_data_l,'dir'), rmdir(dir_job_data_l,'s'); end; mkdir(dir_job_data_l);
if exist(dir_logs_l,'dir'),     rmdir(dir_logs_l,'s');     end; mkdir(dir_logs_l);
if exist(dir_scripts_l,'dir'),  rmdir(dir_scripts_l,'s');  end; mkdir(dir_scripts_l);

%--------------------------------------------------------------------------
% Path to directories on holly
dir_job_data_h = fullfile(dir_root_h,'data');            
dir_logs_h     = fullfile(dir_root_h,'logs');           
dir_scripts_h  = fullfile(dir_root_h,'scripts');

%==========================================================================
%% Create bash scripts that will run on holly (using qsub)

jnam_h     = 'foo_job';        % the name of the t jobs that will run on holly
fun        = 'subject_update'; % the name of a MATLAB function, that should exist in the same folder as this script (parfor_holly). For more info do 'help foo'
jnam_dummy = 'dummy_job';      % the name of the dummy job that will run on holly

[pth_script_parfor,pth_script_dummy] = create_bash_scripts(dir_scripts_l,dir_scripts_h,jnam_h,jnam_dummy,fun,dir_logs_h,dir_matlab_h,dir_pwd_h,t);

%==========================================================================
%% Save a cell array that holds paths to MAT-files, which contains data specific to each job

pth_job_data_array = './pth_job_data_array_h.mat';
pth_job_data_l     = cell(1,t);
pth_job_data_h     = cell(1,t);
for i=1:t      
    pth_job_data_l{i} = fullfile(dir_job_data_l,[fun num2str(i) '_data.mat']);
    pth_job_data_h{i} = fullfile(dir_job_data_h,[fun num2str(i) '_data.mat']);   
    
    x = 0; % variable to be incremented
    save(pth_job_data_l{i},'-mat','x')        
end
clear x
save(pth_job_data_array,'-mat','pth_job_data_h')

%==========================================================================
%% Run code in parallel on holly

SX = [];

fprintf('==========================================\n')   
fprintf('Starting demo...\n')   
for iter=1:10     
    fprintf('iter=%d\n',iter);         
    pause(1); % A short pause, just to make sure i/o has finished writing to disk
    
    %----------------------------------------------------------------------
    % Submit t jobs to holly    
    tic; % start timer
    
    cmd             = ['sshpass -p "' password '" ssh -o StrictHostKeyChecking=no ' username '@holly "source /etc/profile;/opt/gridengine/bin/linux-x64/qsub -l vf=' num2str(RAM) 'G -l h_vmem=' num2str(RAM) 'G ' pth_script_parfor '"'];        
    [status,result] = system(cmd);    
    if status
        fprintf([result '\n'])
        error('status~=0 on Holly!') 
    end
    fprintf(result)
    
    %----------------------------------------------------------------------
    % Submit a dummy job, which waits for the t jobs to finish before starting
    cmd             = ['sshpass -p "' password '" ssh -o StrictHostKeyChecking=no ' username '@holly "source /etc/profile;/opt/gridengine/bin/linux-x64/qsub -l vf=0.1G -l h_vmem=0.1G -hold_jid ' jnam_h ' -cwd ' pth_script_dummy '"'];
    [status,result] = system(cmd);
    if status
        fprintf([result '\n'])
        error('status~=0 for dummy job on Holly!') 
    end
    fprintf(result)
    
    %----------------------------------------------------------------------
    % Check if dummy job has finished
    while 1, 
        pause(1); % A short pause, just to not constantly be sending commands over ssh
        
        cmd             = ['sshpass -p "' password '" ssh -o StrictHostKeyChecking=no ' username '@holly "source /etc/profile;/opt/gridengine/bin/linux-x64/qstat | grep ' jnam_dummy '"'];        
        [status,result] = system(cmd);   
        if isempty(result)
            % holly has finished processing, let's do something with the results
            fprintf('Elapsed time (holly): %d s\n',toc)
            
            SX = global_update(pth_job_data_l,t,iter,SX);
            
            break
        end
    end 
end
fprintf('demo has finished!\n')   
fprintf('==========================================\n')   