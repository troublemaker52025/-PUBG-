----- G Hub lua--------
--------------------------------

----- 硬件与环境参数 --------
FPS = 240
ScreenX = 2560
ScreenY = 1440
MouseDPI = 900  -- 鼠标当前 DPI，900 DPI 下偏移量感受偏大，可通过 YQXS_Y 微调

----- 功能控制键(G Hub 键位，请参考下表进行配置) --------
GHUB_KEY_MAPPINGS = {
    ["G1"] = 1,    -- G1 鼠标左键
    ["G2"] = 2,    -- G2 鼠标右键
    ["G3"] = 3,    -- G3 鼠标中键
    ["G4"] = 4,    -- G4 侧键
    ["G5"] = 6,    -- G5 侧键
    ["G6"] = 5,    -- G6 侧键G
    ["G7"] = 11,   -- G7 鼠标左键侧键
    ["G8"] = 10,   -- G8 鼠标左键侧键
    ["G9"] = 9,    -- G9 鼠标滚轮后键
    ["G10"] = 7,   -- G10 滚轮左侧键
    ["G11"] = 8    -- G11 滚轮右侧键
}

AKM = "G8"         -- AKM 枪械开关

offkey = "G7"      -- 关闭压枪键

----- 压枪模式与微调 ---------
Enable_mode = 2     -- 1: 左键直接压 ---- 2: 右键开镜后左键压枪
YQXS_Y = 1.0       -- Y轴整体缩放 (如果 900 DPI 下拉枪太过，就把这个值改小，如 0.6)
YQXS_X = 1.0       -- X轴整体缩放

----- 初始化后坐力表 --------
Recoil_table = {}

----- AKM 参数 --------
Recoil_table["AKM"] = {
    -- X弹道30个数据，Y弹道47个数据
    Trajectory_x = {0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0}, 
    Trajectory_y = {32, 20, 22, 25, 25,
                    27, 28, 30, 30, 32,
                    32, 32, 34, 34, 34,
                    34, 34, 35, 34, 34,
                    34, 34, 34, 35, 36,
                    35, 35, 35, 35, 35}, 
    RateOfFire = 600,
    max_bullets = 30  -- 新增：限制最大开火数
}

----- 全局状态变量 --------
current_weapon = nil
is_off = false

----- 核心压枪函数 --------
function RecoilControl()
    if current_weapon == nil or is_off then return end
    
    local weapon = Recoil_table[current_weapon]
    if weapon == nil then return end

    -- 计算射速间隔
    local sleep_time = 60000 / weapon.RateOfFire

    -- 条件3：弹道数量以最多的为主 (X和Y数组长度取最大值)
    local len_x = #weapon.Trajectory_x
    local len_y = #weapon.Trajectory_y
    local max_trajectory_len = math.max(len_x, len_y)
    
    -- 实际最大开火数 = min(最大弹道长度, 设定的 max_bullets)
    -- 这样既不会超过表的数据上限，也不会超过你设定的 max_bullets 上限
    local actual_max_bullets = math.min(max_trajectory_len, weapon.max_bullets)

    local bullet_index = 1

    while (IsMouseButtonPressed(1)) do
        -- 模式2检查
        if Enable_mode == 2 then
            if not IsMouseButtonPressed(3) then break end
        end
        
        if is_off then break end

        -- 达到实际最大开火数，退出循环
        if bullet_index > actual_max_bullets then break end

        -- 条件4：保护判断，如果当前序号超过对应数组的长度，则取数组最后一个值
        -- math.min(bullet_index, len_x) 保证了当 bullet_index > len_x 时，只会读取 len_x (即最后一条数据)
        local idx_x = math.min(bullet_index, len_x)
        local idx_y = math.min(bullet_index, len_y)

        -- 获取当前发数的 X 和 Y 偏移量并乘以缩放系数
        local move_x = weapon.Trajectory_x[idx_x] * YQXS_X
        local move_y = weapon.Trajectory_y[idx_y] * YQXS_Y

        -- 执行鼠标移动
        MoveMouseRelative(move_x, move_y)

        -- 等待下一发子弹
        Sleep(sleep_time)

        bullet_index = bullet_index + 1
    end
end

----- 事件监听函数 --------
function OnEvent(event, arg, family)
    EnablePrimaryMouseButtonEvents(true)

    if event == "PROFILE_ACTIVATED" then
        OutputLogMessage("Profile activated | family=%s | arg=%d\n", tostring(family), arg)
    end

    -- 监听按键并根据按键设置当前武器或关闭压枪
    if event == "MOUSE_BUTTON_PRESSED" then
        OutputLogMessage("LMB pressed | family=%s | arg=%d\n", tostring(family), arg)
        if arg == GHUB_KEY_MAPPINGS[AKM] then
            current_weapon = "AKM"
            is_off = false
            OutputLogMessage("Weapon: AKM | Recoil: %s\n", is_off and "OFF" or "ON")
        elseif arg == GHUB_KEY_MAPPINGS[offkey] then
            is_off = true
            OutputLogMessage("Recoil OFF\n")
        end
    end

    if event == "MOUSE_BUTTON_PRESSED" and arg == GHUB_KEY_MAPPINGS["G1"] then
        OutputLogMessage("LMB pressed | family=%s | mode=%d\n", tostring(family), Enable_mode)

        if Enable_mode == 1 then
            RecoilControl()
            OutputLogMessage("Mode1 RecoilControl()\n")
        elseif Enable_mode == 2 then
            if IsMouseButtonPressed(3) then
                RecoilControl()
                OutputLogMessage("Mode2 RecoilControl()\n")
            else
                OutputLogMessage("Mode2 waiting for RMB\n")
            end
        else
            OutputLogMessage("Invalid mode: %d\n", Enable_mode)
        end
    end
end
