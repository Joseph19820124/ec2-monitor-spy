#!/bin/bash
#
# EC2 状态监控脚本 - 探子来报
# 每6小时检查目标EC2的状态并通过SNS发送邮件通知
#

# 配置
TARGET_INSTANCE_ID="i-0a65e38615afa91ca"
TARGET_INSTANCE_NAME="large"
SNS_TOPIC_ARN="arn:aws:sns:us-east-2:360529135522:ec2-monitor-alerts"
REGION="us-east-2"
LOG_FILE="/home/ec2-user/joseph/proj/monitor-ec2/logs/monitor.log"

# 获取当前时间（上海时区）
TIMESTAMP=$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')
HOUR=$(TZ='Asia/Shanghai' date '+%H')

# 获取EC2状态
STATUS=$(aws ec2 describe-instances \
  --instance-ids "$TARGET_INSTANCE_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>&1)

# 检查命令是否成功
if [ $? -ne 0 ]; then
  STATUS="ERROR: $STATUS"
fi

# 根据时间判断预期状态
# 08:00 开机, 18:00 关机 (上海时间)
if [ "$HOUR" -ge 8 ] && [ "$HOUR" -lt 18 ]; then
  EXPECTED="running"
  PERIOD="工作时段 (08:00-18:00)"
else
  EXPECTED="stopped"
  PERIOD="休息时段 (18:00-08:00)"
fi

# 判断状态是否符合预期
if [ "$STATUS" == "$EXPECTED" ]; then
  VERDICT="✅ 符合预期"
  SUBJECT="[EC2监控] 正常 - $TARGET_INSTANCE_NAME 状态: $STATUS"
else
  VERDICT="⚠️ 状态异常"
  SUBJECT="[EC2监控] 异常 - $TARGET_INSTANCE_NAME 状态: $STATUS (预期: $EXPECTED)"
fi

# 构建消息
MESSAGE="🔍 探子来报

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EC2 状态监控报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📅 检查时间: $TIMESTAMP (上海时间)
🖥️ 目标实例: $TARGET_INSTANCE_NAME ($TARGET_INSTANCE_ID)
📊 当前状态: $STATUS
⏰ 当前时段: $PERIOD
🎯 预期状态: $EXPECTED
📋 判定结果: $VERDICT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EventBridge Scheduler 规则:
- StartEC2-8AM-Shanghai (每天08:00开机)
- StopEC2-6PM-Shanghai  (每天18:00关机)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

此消息由 singleton (i-0752def97b789db06) 自动发送"

# 记录日志
echo "[$TIMESTAMP] Status: $STATUS, Expected: $EXPECTED, Verdict: $VERDICT" >> "$LOG_FILE"

# 发送SNS通知
aws sns publish \
  --topic-arn "$SNS_TOPIC_ARN" \
  --region "$REGION" \
  --subject "$SUBJECT" \
  --message "$MESSAGE"

echo "[$TIMESTAMP] 通知已发送"
