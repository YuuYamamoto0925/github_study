#!/bin/bash

# 0.Var Setting
SCRIPT_DIR=""$(cd ""$(dirname ""$0"")"" && pwd)""
mkdir -p ""${SCRIPT_DIR}/logs""
LOG_DIR=""${SCRIPT_DIR}/logs""

LOG_FILE=""${LOG_DIR}/GitRunner_Token_REG_$(date '+%Y%m%d_%H%M%S').log""
JSON_FILE=""${LOG_DIR}/GitRunner_Token_REG.json""

SECRET_NAME=""test-tokens"" // AWS シークレットマネージャー名
REGION=""ap-northeast-1""           // AWS 利用リージョン
DOMAIN_URL=""https://git.test.jp""  // 対象GitLabドメイン

# 1.AWS Secrets Manager Get Key and vales
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [START] 1.AWS Secrets Manager Get Key and vales"" >> ""$LOG_FILE""
aws secretsmanager get-secret-value --secret-id ""$SECRET_NAME"" --region ""$REGION"" > ""$JSON_FILE"" 2>&1
check=""$?""

chown -R gitlab-runner:gitlab-runner ""${LOG_DIR}""
find ""${LOG_DIR}"" -type d -exec chmod 0700 {} +
find ""${LOG_FILE}"" -type f -exec chmod 0400 {} +

if [ ""$check"" -eq 0 ]; then
  echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [EXEC] AWS Secrets Manager API Success"" >> ""$LOG_FILE""
else
  echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] AWS Secrets Manager API Error code:${check}"" >> ""$LOG_FILE""
  echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] 1.AWS Secrets Manager Get Key and vales"" >> ""$LOG_FILE""
  rm -f ""${JSON_FILE}""
  exit 1
fi
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [END] 1.AWS Secrets Manager Get Key and vales"" >> ""$LOG_FILE""

# 2.Get Json File Key Check
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [START] 2.Get Json File Key Check"" >> ""$LOG_FILE""
SECRET_STRING=$(jq -r '.SecretString // empty' ${JSON_FILE})
COUNT=$(echo ""$SECRET_STRING"" | jq 'length' 2>/dev/null || echo 0)
if [ ""$COUNT"" -gt 0 ]; then
  echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [EXEC] JSON KEY LIST:${COUNT}"" >> ""$LOG_FILE""
else
  echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] JSON KEY LIST NOT"" >> ""$LOG_FILE""
  echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] 2.Get Json File Key Check"" >> ""$LOG_FILE""
  rm -f ""${JSON_FILE}""
  exit 1
fi
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [END] 2.Get Json File Key Check"" >> ""$LOG_FILE""

# 3.Docker Images Maintenance
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [START] 3.Docker Images Maintenance"" >> ""$LOG_FILE""
docker container prune -f >> ""$LOG_FILE"" 2>&1
#docker image prune -a -f --filter ""until=720h"" >> ""$LOG_FILE"" 2>&1
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [END] 3.Docker Images Maintenance"" >> ""$LOG_FILE""

# 4.GitLabRunnner Key and vales Re-registration
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [START] 4.GitLabRunnner Key and vales Re-registration"" >> ""$LOG_FILE""
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [EXEC] GitLabRunnner Token List Info"" >> ""$LOG_FILE""
gitlab-runner list 2>&1 | sed -E 's/glrt-[A-Za-z0-9._-]+/glrt-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/g' >> ""$LOG_FILE"" 2>&1

echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [EXEC] GitLabRunnner Token List Delete"" >> ""$LOG_FILE""
gitlab-runner verify --delete >> ""$LOG_FILE"" 2>&1
gitlab-runner unregister --all-runners >> ""$LOG_FILE"" 2>&1

echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [EXEC] GitLabRunnner Token List Info"" >> ""$LOG_FILE""
gitlab-runner list 2>&1 | sed -E 's/glrt-[A-Za-z0-9._-]+/glrt-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/g' >> ""$LOG_FILE"" 2>&1

echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [EXEC] GitLabRunnner Token Re-registration"" >> ""$LOG_FILE""
SECRET_STRING=$(jq -r '.SecretString // empty' ${JSON_FILE})
  echo ""$SECRET_STRING"" | jq -r 'to_entries[] | ""\(.key) \(.value)""' | while read -r KEY VALUE; do
    gitlab-runner register --non-interactive --url ""${DOMAIN_URL}"" --token ""${VALUE}"" --executor ""docker"" --docker-image ""alpine:latest"" --docker-pull-policy ""always"" --description ""${KEY}"" >> ""$LOG_FILE"" 2>&1
  done

echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [EXEC] GitLabRunnner Token List Info"" >> ""$LOG_FILE""
gitlab-runner list 2>&1 | sed -E 's/glrt-[A-Za-z0-9._-]+/glrt-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/g' >> ""$LOG_FILE"" 2>&1

echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [END] 4.GitLabRunnner Key and vales Re-registration"" >> ""$LOG_FILE""

# 5.LogFile Delete
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [START] 5.LogFile Delete"" >> ""$LOG_FILE""
rm -f ""${JSON_FILE}""
find ""${LOG_DIR}"" -type f -name ""GitRunner_Token_REG_*.log"" -mtime +7 -delete
echo ""[$(date '+%Y-%m-%d %H:%M:%S')] [END] 5.LogFile Delete"" >> ""$LOG_FILE""

exit 0
