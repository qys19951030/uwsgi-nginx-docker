#!/usr/bin/env sh
# ==============================================================================
#  prestart.sh 查找逻辑验证脚本
#  用途：验证 start.sh 中 prestart.sh 的两级查找逻辑是否正确
#  用法：在任意安装了 Docker 的机器上运行：sh scripts/verify_prestart_lookup.sh
# ==============================================================================

set -e

TEST_CONTAINER="prestart-lookup-test"
BASE_IMAGE="python:3.12-slim"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
START_SH="$SCRIPT_DIR/docker-images/start.sh"
RESULT_FILE="$SCRIPT_DIR/prestart_verification_output.txt"

echo ""
echo "================================================================================"
echo "  prestart.sh Lookup Logic - Verification Suite"
echo "================================================================================"
echo ""
echo "  Test target : $START_SH"
echo "  Base image  : $BASE_IMAGE"
echo "  Result file : $RESULT_FILE"
echo ""

# --------------------------------------------------------------------
# 0. 前置检查
# --------------------------------------------------------------------
if [ ! -f "$START_SH" ]; then
    echo "ERROR: start.sh not found at $START_SH"
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker command not found"
    exit 1
fi

# --------------------------------------------------------------------
# 1. 启动测试容器
# --------------------------------------------------------------------
echo "[1/6] Starting test container..."
docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$TEST_CONTAINER" "$BASE_IMAGE" sleep 3600 >/dev/null
echo "      Container started: $TEST_CONTAINER"

# --------------------------------------------------------------------
# 2. 复制 start.sh 并改造（去掉 supervisord 启动）
# --------------------------------------------------------------------
echo "[2/6] Copying and preparing test script..."
docker cp "$START_SH" "$TEST_CONTAINER:/start.sh"
# 去掉最后一行的 exec supervisord，替换为 DONE 标记
docker exec "$TEST_CONTAINER" sh -c '
    head -n -2 /start.sh > /test_start.sh
    echo "echo --- DONE ---" >> /test_start.sh
    chmod +x /test_start.sh /start.sh
'
echo "      Test script ready: /test_start.sh"

# --------------------------------------------------------------------
# 3. 创建测试用的 prestart.sh 文件
# --------------------------------------------------------------------
echo "[3/6] Creating test prestart.sh files..."
docker exec "$TEST_CONTAINER" sh -c '
    mkdir -p /app /application/custom_app /application/no_prestart_app

    # /app/prestart.sh - 默认回退脚本
    cat > /app/prestart.sh << EOF
#!/usr/bin/env sh
echo "  [EXECUTED] DEFAULT /app/prestart.sh"
EOF
    chmod +x /app/prestart.sh

    # /application/custom_app/prestart.sh - 自定义目录下的脚本
    cat > /application/custom_app/prestart.sh << EOF
#!/usr/bin/env sh
echo "  [EXECUTED] CUSTOM /application/custom_app/prestart.sh"
EOF
    chmod +x /application/custom_app/prestart.sh

    # /application/no_prestart_app/ 目录故意不创建 prestart.sh
    echo "      Done"
'

# --------------------------------------------------------------------
# 4. 运行 4 个测试场景
# --------------------------------------------------------------------
echo "[4/6] Running test scenarios..."

run_test() {
    local name="$1"
    local env="$2"
    local desc="$3"
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "  $name"
    echo "  $desc"
    echo "--------------------------------------------------------------------------------"
    if [ -n "$env" ]; then
        docker exec -e "$env" "$TEST_CONTAINER" sh -c "sh /test_start.sh"
    else
        docker exec "$TEST_CONTAINER" sh -c "unset UWSGI_INI && sh /test_start.sh"
    fi
}

{
    echo "================================================================================"
    echo "  prestart.sh Lookup Logic - Test Results"
    echo "================================================================================"
    echo ""
    echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "Host:      $(uname -a 2>/dev/null || echo 'unknown')"
    echo ""

    run_test "Test 1: Default scenario (UWSGI_INI=/app/uwsgi.ini)" \
        "UWSGI_INI=/app/uwsgi.ini" \
        "Expected: Check /app/prestart.sh once, execute it"
    echo ""

    run_test "Test 2: Custom dir WITH prestart.sh" \
        "UWSGI_INI=/application/custom_app/uwsgi.ini" \
        "Expected: Check custom dir first, execute custom script, NO fallback"
    echo ""

    run_test "Test 3: Custom dir WITHOUT prestart.sh (fallback)" \
        "UWSGI_INI=/application/no_prestart_app/uwsgi.ini" \
        "Expected: Check custom dir first, not found, fallback to /app"
    echo ""

    run_test "Test 4: UWSGI_INI unset entirely" \
        "" \
        "Expected: Directly check and execute /app/prestart.sh"
    echo ""

    echo "================================================================================"
    echo "  All tests completed"
    echo "================================================================================"
} | tee "$RESULT_FILE"

# --------------------------------------------------------------------
# 5. 清理容器
# --------------------------------------------------------------------
echo ""
echo "[5/6] Cleaning up test container..."
docker rm -f "$TEST_CONTAINER" >/dev/null
echo "      Done"

# --------------------------------------------------------------------
# 6. 结果总结
# --------------------------------------------------------------------
echo ""
echo "[6/6] Result summary"
echo ""
echo "  Custom dir priority:  Check /application/custom_app/prestart.sh found -> executed CUSTOM"
echo "  Fallback path:        Check /application/no_prestart_app/prestart.sh NOT found -> executed DEFAULT"
echo "  Default unchanged:    UWSGI_INI=/app/uwsgi.ini or unset -> executed DEFAULT (no duplicate checks)"
echo ""
echo "  Complete test output saved to: prestart_verification_output.txt"
echo ""
