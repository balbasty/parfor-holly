function [username,password] = read_user_details(fname)
fid = fopen(fname);

username = fgetl(fid);
password = fgetl(fid);

fclose(fid);