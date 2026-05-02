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

    -- 计算射速间隔(毫秒)
    local sleep_time = 60000 / weapon.RateOfFire

    -- 条件3：弹道数量以最多的为主 (X和Y数组长度取最大值)
    local len_x = #weapon.Trajectory_x
    local len_y = #weapon.Trajectory_y
    local max_trajectory_len = math.max(len_x, len_y)
    
    -- 实际最大开火数 = min(最大弹道长度, 设定的 max_bullets)
    local actual_max_bullets = math.min(max_trajectory_len, weapon.max_bullets)

    -- 【新增】平滑步进间隔(毫秒) 
    -- G Hub的Sleep精度大约在2~10ms，建议设为3~5之间。
    -- 设为4表示：将每一发的移动切分为每4毫秒移动一小步，既不卡顿也不超算力
    local smooth_interval = 4 

    local bullet_index = 1

    while (IsMouseButtonPressed(1)) do
        -- 模式2检查
        if Enable_mode == 2 then
            if not IsMouseButtonPressed(3) then break end
        end
        
        if is_off then break end

        -- 达到实际最大开火数，退出循环
        if bullet_index > actual_max_bullets then break end

        local idx_x = math.min(bullet_index, len_x)
        local idx_y = math.min(bullet_index, len_y)

        -- 获取当前发数的 X 和 Y 偏移量并乘以缩放系数
        local move_x = weapon.Trajectory_x[idx_x] * YQXS_X
        local move_y = weapon.Trajectory_y[idx_y] * YQXS_Y

        -- 【新增】计算该发子弹需要切分成多少步移动
        local steps = math.floor(sleep_time / smooth_interval)
        if steps < 1 then steps = 1 end

        -- 每步理论移动量(浮点数)
        local step_x = move_x / steps
        local step_y = move_y / steps

        -- 【新增】累计误差平滑法
        -- 利用浮点数累加，解决像素不能切分导致总偏移量不守恒的问题
        local acc_x = 0
        local acc_y = 0

        for i = 1, steps do
            -- 【关键优化】实时检测按键状态，如果中途松开鼠标或右键，立即停止，防止松手后鼠标继续往下拉
            if not IsMouseButtonPressed(1) then return end
            if Enable_mode == 2 and not IsMouseButtonPressed(3) then return end
            if is_off then return end

            acc_x = acc_x + step_x
            acc_y = acc_y + step_y

            -- 四舍五入取整，确保总位移最接近理论值
            local dx = math.floor(acc_x + 0.5)
            local dy = math.floor(acc_y + 0.5)

            -- 只有当实际需要移动时才调用鼠标移动指令，节省算力
            if dx ~= 0 or dy ~= 0 then
                MoveMouseRelative(dx, dy)
                -- 减去已经移动的量，保留微小误差进入下一次循环累加
                acc_x = acc_x - dx
                acc_y = acc_y - dy
            end

            Sleep(smooth_interval)
        end

        -- 【新增】步长时间补偿
        -- 因为 steps * smooth_interval 可能会略小于实际的射速 sleep_time
        -- 补足剩余的时间，确保压枪节奏不被加快
        local elapsed = steps * smooth_interval
        if elapsed < sleep_time then
            Sleep(sleep_time - elapsed)
        end

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
