%% Basic Info
%========================================================
% Modified read_write.m (a sample code file)

% Dynamixel model: XM430-W210-R
% https://emanual.robotis.com/docs/kr/dxl/x/xm430-w210/
% Communication: RS-485 (Used a U2D2 module)
% Protocol ver: 2.0 (a protocol version for X series)
%========================================================

%%
clc;
clear all;

lib_name = '';

if strcmp(computer, 'PCWIN')
    lib_name = 'dxl_x86_c';
elseif strcmp(computer, 'PCWIN64')
    lib_name = 'dxl_x64_c';
elseif strcmp(computer, 'GLNX86')
    lib_name = 'libdxl_x86_c';
elseif strcmp(computer, 'GLNXA64')
    lib_name = 'libdxl_x64_c';
elseif strcmp(computer, 'MACI64')
    lib_name = 'libdxl_mac_c';
end

%% Load libraries
if ~libisloaded(lib_name)
    [notfound, warnings] = loadlibrary(lib_name, 'dynamixel_sdk.h', 'addheader', 'port_handler.h', 'addheader', 'packet_handler.h');
end

%% Control table address
ADDR_OPERATING_MODE      = 11;
ADDR_TORQUE_ENABLE       = 64;

ADDR_GOAL_POSITION       = 116;
ADDR_PRESENT_POSITION    = 132;
ADDR_GOAL_VELOCITY       = 104;
ADDR_PRESENT_VELOCITY    = 128;

ADDR_GOAL_CURRENT        = 102;
ADDR_PRESENT_CURRENT     = 126;
ADDR_GOAL_PWM            = 100;
ADDR_PRESENT_PWM         = 124;

%% Protocol version
PROTOCOL_VERSION            = 2.0;          % See which protocol version is used in the Dynamixel

%% Default settings
DXL_ID                      = 1;            % Dynamixel ID: 1
BAUDRATE                    = 57600;
DEVICENAME                  = 'COM5';       % Check which port is being used on your controller
% ex) Windows: 'COM1'   Linux: '/dev/ttyUSB0' Mac: '/dev/tty.usbserial-*'

TORQUE_ENABLE               = 1;            % Value for enabling the torque
TORQUE_DISABLE              = 0;            % Value for disabling the torque

DXL_MINIMUM_POSITION_VALUE  = 0;
DXL_MAXIMUM_POSITION_VALUE  = 4095;
DXL_MINIMUM_VELOCITY_VALUE  = -330;
DXL_MAXIMUM_VELOCITY_VALUE  = 330;

DXL_MINIMUM_CURRENT_VALUE   = -1193;
DXL_MAXIMUM_CURRENT_VALUE   = 1193;
DXL_MINIMUM_PWM_VALUE       = -885;
DXL_MAXIMUM_PWM_VALUE       = 885;

DXL_MOVING_STATUS_THRESHOLD = 5;            % Threshold for the position, velocity, and voltage control modes
DXL_MOVING_STATUS_THRESHOLD_CURRENT = 1;    % Threshold for the current control mode

ESC_CHARACTER               = 'e';          % Key for escaping loop

COMM_SUCCESS                = 0;            % Communication Success result value
COMM_TX_FAIL                = -1001;        % Communication Tx Failed

%% Initialize PortHandler Structs
% Set the port path
% Get methods and members of PortHandlerLinux or PortHandlerWindows
port_num = portHandler(DEVICENAME);

%% Initialize PacketHandler Structs
packetHandler();

dxl_comm_result = COMM_TX_FAIL;             % Communication result
dxl_error = 0;                              % Dynamixel error

dxl_present_position = 0;                   % Present position
dxl_present_velocity = 0;                   % Present velocity
dxl_present_current  = 0;                   % Present current
dxl_present_pwm      = 0;                   % Present pwm

%% Open port
if (openPort(port_num))
    fprintf('Succeeded to open the port!\n');
else
    unloadlibrary(lib_name);
    fprintf('Failed to open the port!\n');
    input('Press any key to terminate...\n');
    return;
end

%% Set port baudrate
if (setBaudRate(port_num, BAUDRATE))
    fprintf('Succeeded to change the baudrate!\n');
else
    unloadlibrary(lib_name);
    fprintf('Failed to change the baudrate!\n');
    input('Press any key to terminate...\n');
    return;
end

%% Disable Dynamixel Torque
write1ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_TORQUE_ENABLE, TORQUE_DISABLE);
dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
if dxl_comm_result ~= COMM_SUCCESS
    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
elseif dxl_error ~= 0
    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
end

%% Operating mode (Only works when Torque Enable == 0)
while 1
    OPERATING_MODE_VALUE = input('Select an operating mode:\n 0 (current control)\n 1 (velocity control)\n 3 (position control)\n 5 (current-based control)\n 16 (voltage control) \n')
    if OPERATING_MODE_VALUE == 0
        fprintf('You selected the current control mode \n');
        break;
    elseif OPERATING_MODE_VALUE == 1
        fprintf('You selected the velocity control mode \n');
        break;
    elseif OPERATING_MODE_VALUE == 3
        fprintf('You selected the position control mode \n');
        break;
    elseif OPERATING_MODE_VALUE == 16
        fprintf('You selected the voltage control mode \n');
        break;
    elseif OPERATING_MODE_VALUE == 5
        fprintf('You selected the current-based control mode \n');
        break;
    else
        fprintf('You typed a wrong one. Try again. \n');
    end
end

write1ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_OPERATING_MODE, OPERATING_MODE_VALUE);

%% Enable Dynamixel Torque
write1ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_TORQUE_ENABLE, TORQUE_ENABLE);
dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
if dxl_comm_result ~= COMM_SUCCESS
    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
elseif dxl_error ~= 0
    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
else
    fprintf('Dynamixel has been successfully connected \n');
end

%% Motor control
while 1
    if input('Press any key to continue! (or input e to quit!) \n', 's') == ESC_CHARACTER
        break;
    end
    
    if OPERATING_MODE_VALUE == 3
        %% position control (4 Byte)
        while 1
            completed = 0;
            goal_position = input('Input the goal position (from 0 to 4095) \n');
            if goal_position < DXL_MINIMUM_POSITION_VALUE
                fprintf('Out of range \n')
                break;
            elseif goal_position > DXL_MAXIMUM_POSITION_VALUE
                fprintf('Out of range \n')
                break;
            end
            
            % Write a goal position
            write4ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_GOAL_POSITION, typecast(int32(goal_position), 'uint32'));
            dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
            if dxl_comm_result ~= COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
            end
            
            while 1
                % Read the present position
                dxl_present_position = read4ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_POSITION);
                dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
                if dxl_comm_result ~= COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
                end
                
                fprintf('[ID:%03d] GoalPos:%03d  PresPos:%03d\n', DXL_ID, goal_position, typecast(uint32(dxl_present_position), 'int32'));
                
                if ~(abs(goal_position - typecast(uint32(dxl_present_position), 'int32')) > DXL_MOVING_STATUS_THRESHOLD)
                    completed = 1;
                    break;
                end
            end
            
            if completed == 1
                break;
            end
        end
        
        
    elseif OPERATING_MODE_VALUE == 1
        %% velocity control (4 Byte)
        while 1
            completed = 0;
            goal_velocity = input('Input the goal velocity (from -330 to 330) \n');
            if goal_velocity < DXL_MINIMUM_VELOCITY_VALUE
                fprintf('Out of range \n')
                break;
            elseif goal_velocity > DXL_MAXIMUM_VELOCITY_VALUE
                fprintf('Out of range \n')
                break;
            end
            
            % Write a goal velosity
            write4ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_GOAL_VELOCITY, typecast(int32(goal_velocity), 'uint32'));
            dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
            if dxl_comm_result ~= COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
            end
            
            while 1
                % Read the present velocity
                dxl_present_velocity = read4ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_VELOCITY);
                dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
                if dxl_comm_result ~= COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
                end
                
                fprintf('[ID:%03d] GoalVel:%03d  PresVel:%03d\n', DXL_ID, goal_velocity, typecast(uint32(dxl_present_velocity), 'int32'));
                
                if ~(abs(goal_velocity - typecast(uint32(dxl_present_velocity), 'int32')) > DXL_MOVING_STATUS_THRESHOLD)
                    completed = 1;
                    break;
                end
            end
            
            if completed == 1
                break;
            end
        end
        
    elseif OPERATING_MODE_VALUE == 0
        %% Current control (2 Byte)
        while 1
            completed = 0;
            goal_current = input('Input the goal current (from -15 to 10) \n');
            if goal_current < -15
                fprintf('Out of range \n')
                break;
            elseif goal_current > 10
                fprintf('Out of range \n')
                break;
            end
            
            % Write a goal current
            write2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_GOAL_CURRENT, typecast(int16(goal_current), 'uint16'));
            dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
            if dxl_comm_result ~= COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
            end
            
            while 1
                % Read the present current
                dxl_present_current = read2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_CURRENT);
                dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
                if dxl_comm_result ~= COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
                end
                
                dxl_present_velocity = read4ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_VELOCITY);
                
                fprintf('[ID:%03d] GoalCur:%03d  PresCur:%03d  PressVel:%03d\n', DXL_ID, goal_current, typecast(uint16(dxl_present_current), 'int16'), typecast(uint32(dxl_present_velocity), 'int32'));
                
                if ~(abs(goal_current - typecast(uint16(dxl_present_current), 'int16')) > DXL_MOVING_STATUS_THRESHOLD_CURRENT)
                    completed = 1;
                    break;
                end
            end
            
            if completed == 1
                break;
            end
        end
        
    elseif OPERATING_MODE_VALUE == 16
        %% Voltage control (2 Byte)
        while 1
            completed = 0;
            goal_pwm = input('Input the goal PWM (from -885 to 885) \n');
            if goal_pwm < DXL_MINIMUM_PWM_VALUE
                fprintf('Out of range \n')
                break;
            elseif goal_pwm > DXL_MAXIMUM_PWM_VALUE
                fprintf('Out of range \n')
                break;
            end
            
            % Write a goal PWM
            write2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_GOAL_PWM, typecast(int16(goal_pwm), 'uint16'));
            dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
            if dxl_comm_result ~= COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
            end
            
            while 1
                % Read the present PWM
                dxl_present_pwm = read2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_PWM);
                dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
                if dxl_comm_result ~= COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
                end
                
                fprintf('[ID:%03d] GoalPWM:%03d  PresPWM:%03d\n', DXL_ID, goal_pwm, typecast(uint16(dxl_present_pwm), 'int16'));
                
                if ~(abs(goal_pwm - typecast(uint16(dxl_present_pwm), 'int16')) > DXL_MOVING_STATUS_THRESHOLD)
                    completed = 1;
                    break;
                end
            end
            
            if completed == 1
                break;
            end
        end
        
    elseif OPERATING_MODE_VALUE == 5
        %% Current-based position control (4 Byte for position, 2 Byte for current and pwm)
        while 1
            completed = 0;
            goal_position = input('Input the goal position (from -1048575 to 1048575) \n');
            if goal_position < -1048575
                fprintf('Out of range \n')
                break;
            elseif goal_position > 1048575
                fprintf('Out of range \n')
                break;
            end
            
            goal_current = input('Input the goal current (from -1193 to 1193) \n');
            if goal_current < -1193
                fprintf('Out of range \n')
                break;
            elseif goal_current > 1193
                fprintf('Out of range \n')
                break;
            end
            
            goal_pwm = input('Input the goal PWM (from -885 to 885) \n');
            if goal_pwm < DXL_MINIMUM_PWM_VALUE
                fprintf('Out of range \n')
                break;
            elseif goal_pwm > DXL_MAXIMUM_PWM_VALUE
                fprintf('Out of range \n')
                break;
            end
            
            % Write a goal position
            write4ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_GOAL_POSITION, typecast(int32(goal_position), 'uint32'));
            dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
            if dxl_comm_result ~= COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
            end
            
            % Write a goal current and a goal PWM
            write2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_GOAL_CURRENT, typecast(int16(goal_current), 'uint16'));
            write2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_GOAL_PWM, typecast(int16(goal_pwm), 'uint16'));
            
            while 1
                % Read the present position
                dxl_present_position = read4ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_POSITION);
                dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
                if dxl_comm_result ~= COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
                end
                
                dxl_present_current = read2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_CURRENT);
                dxl_present_pwm = read2ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_PRESENT_PWM);
                
                fprintf('[ID:%03d] GoalPos:%03d  PresPos:%03d  PresCur:%03d  PresPWM:%03d \n', DXL_ID, goal_position, typecast(uint32(dxl_present_position), 'int32'), typecast(uint16(dxl_present_current), 'int16'), typecast(uint16(dxl_present_pwm), 'int16'));
                
                if ~(abs(goal_position - typecast(uint32(dxl_present_position), 'int32')) > DXL_MOVING_STATUS_THRESHOLD)
                    completed = 1;
                    break;
                end
            end
            
            if completed == 1
                break;
            end
        end
    end
end

%% Disable Dynamixel Torque
write1ByteTxRx(port_num, PROTOCOL_VERSION, DXL_ID, ADDR_TORQUE_ENABLE, TORQUE_DISABLE);
dxl_comm_result = getLastTxRxResult(port_num, PROTOCOL_VERSION);
dxl_error = getLastRxPacketError(port_num, PROTOCOL_VERSION);
if dxl_comm_result ~= COMM_SUCCESS
    fprintf('%s\n', getTxRxResult(PROTOCOL_VERSION, dxl_comm_result));
elseif dxl_error ~= 0
    fprintf('%s\n', getRxPacketError(PROTOCOL_VERSION, dxl_error));
end

%% Close port
closePort(port_num);

%% Unload Library
unloadlibrary(lib_name);

close all;
clear all;
