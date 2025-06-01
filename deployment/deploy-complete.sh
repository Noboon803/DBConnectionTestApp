#!/bin/bash

# Complete deployment script for both web and db servers
# WebサーバーとDBサーバーの両方をデプロイするための統合スクリプト

set -e

echo "=== DBConnectionTestApp Complete Deployment ==="
echo "Timestamp: $(date)"

# S3バケット設定の確認
S3_BUCKET="${S3_BUCKET:-your-deployment-bucket}"
if [ "$S3_BUCKET" = "your-deployment-bucket" ]; then
    echo "⚠️  Warning: Please set S3_BUCKET environment variable"
    echo "   Example: export S3_BUCKET=my-actual-bucket-name"
    read -p "Continue with default bucket name? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled. Please set S3_BUCKET and try again."
        exit 1
    fi
fi

# プロジェクトルートに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "📁 Working directory: $(pwd)"
echo "🪣 S3 Bucket: $S3_BUCKET"

# ビルドディレクトリの作成
echo "📦 Creating build directory..."
mkdir -p build

# 1. DBサーバー設定のパッケージング
echo ""
echo "=== Step 1: Packaging DB Server Configuration ==="
if [ -f "deployment/build-and-package-db.sh" ]; then
    chmod +x deployment/build-and-package-db.sh
    ./deployment/build-and-package-db.sh
else
    echo "❌ DB packaging script not found"
    exit 1
fi

# 2. Webサーバーのビルドとパッケージング
echo ""
echo "=== Step 2: Building Web Server ==="
if [ -f "deployment/build-and-package.sh" ]; then
    chmod +x deployment/build-and-package.sh
    ./deployment/build-and-package.sh
else
    echo "❌ Web server packaging script not found"
    exit 1
fi

# 3. S3へのアップロード
echo ""
echo "=== Step 3: Uploading to S3 ==="

# S3バケットの存在確認
if aws s3 ls "s3://$S3_BUCKET" > /dev/null 2>&1; then
    echo "✅ S3 bucket '$S3_BUCKET' is accessible"
else
    echo "❌ Cannot access S3 bucket '$S3_BUCKET'"
    echo "   Please check:"
    echo "   - Bucket name is correct"
    echo "   - AWS credentials are configured"
    echo "   - Bucket permissions allow access"
    exit 1
fi

# DBサーバー設定のアップロード
echo "📤 Uploading DB server configuration..."
if aws s3 sync build/db-server-package/ s3://$S3_BUCKET/db-server/ --delete; then
    echo "✅ DB server configuration uploaded"
else
    echo "❌ Failed to upload DB server configuration"
    exit 1
fi

# Webサーバーパッケージのアップロード
echo "📤 Uploading web server package..."
if [ -f "build/webserver-latest.tar.gz" ]; then
    if aws s3 cp build/webserver-latest.tar.gz s3://$S3_BUCKET/webserver/; then
        echo "✅ Web server package uploaded"
    else
        echo "❌ Failed to upload web server package"
        exit 1
    fi
else
    echo "❌ Web server package not found: build/webserver-latest.tar.gz"
    exit 1
fi

# 4. デプロイスクリプトの準備
echo ""
echo "=== Step 4: Preparing Deployment Scripts ==="

# デプロイ用のディレクトリを作成
DEPLOY_DIR="build/deployment-ready"
mkdir -p "$DEPLOY_DIR"

# DBサーバー用ユーザーデータの準備
echo "📝 Preparing DB server user data..."
sed "s/your-deployment-bucket/$S3_BUCKET/g" deployment/ec2-dbserver-userdata.sh > "$DEPLOY_DIR/ec2-dbserver-userdata.sh"

# Webサーバー用ユーザーデータの準備
echo "📝 Preparing web server user data..."
if [ -f "deployment/ec2-webserver-userdata.sh" ]; then
    sed "s/your-deployment-bucket/$S3_BUCKET/g" deployment/ec2-webserver-userdata.sh > "$DEPLOY_DIR/ec2-webserver-userdata.sh"
else
    echo "⚠️  Web server user data script not found, skipping..."
fi

# デプロイ手順書を作成
cat > "$DEPLOY_DIR/DEPLOYMENT_GUIDE.md" << EOF
# EC2 Deployment Guide

## S3アーティファクト

✅ DB Server Configuration: s3://$S3_BUCKET/db-server/
✅ Web Server Package: s3://$S3_BUCKET/webserver/webserver-latest.tar.gz

## デプロイ手順

### 1. DBサーバーEC2の起動

1. **EC2コンソールでインスタンスを起動**
   - AMI: Amazon Linux 2
   - Instance Type: t3.micro 以上
   - Security Group: MySQL/Aurora (Port 3306)

2. **ユーザーデータの設定**
   \`ec2-dbserver-userdata.sh\` の内容をユーザーデータに貼り付け

3. **セキュリティグループ設定**
   \`\`\`
   Type: MySQL/Aurora
   Protocol: TCP
   Port: 3306
   Source: WebサーバーのSecurity Group ID
   \`\`\`

### 2. WebサーバーEC2の起動

1. **ec2-webserver-userdata.sh を編集**
   - DB_HOST をDBサーバーのプライベートIPに設定

2. **EC2インスタンスを起動**
   - AMI: Amazon Linux 2
   - Instance Type: t3.micro 以上
   - Security Group: HTTP (80), HTTPS (443), Custom TCP (3000)

### 3. 動作確認

1. **DBサーバー確認**
   \`\`\`bash
   # SSH接続後
   sudo /opt/mysql/manage-db.sh status
   \`\`\`

2. **Webサーバー確認**
   \`\`\`bash
   # ブラウザで確認
   http://WebサーバーパブリックIP:3000
   
   # API確認
   curl http://WebサーバーパブリックIP:3000/api/health
   curl http://WebサーバーパブリックIP:3000/api/db-test
   \`\`\`

## トラブルシューティング

### DBサーバーが起動しない
\`\`\`bash
sudo tail -f /var/log/user-data.log
sudo /opt/mysql/manage-db.sh logs
\`\`\`

### Webサーバーが起動しない
\`\`\`bash
sudo tail -f /var/log/cloud-init-output.log
sudo pm2 logs webserver
\`\`\`

### 接続エラー
1. セキュリティグループの設定確認
2. DBサーバーのプライベートIP確認
3. DB_HOST設定の確認

## 管理コマンド

### DBサーバー
\`\`\`bash
sudo /opt/mysql/manage-db.sh start|stop|restart|status|logs|backup
\`\`\`

### Webサーバー
\`\`\`bash
sudo pm2 list|restart|logs
\`\`\`
EOF

# デプロイメント情報の表示
echo ""
echo "=== Deployment Packages Ready ==="
echo "📁 Build artifacts:"
ls -la build/

echo ""
echo "📋 S3 Contents:"
echo "🗂️  DB Server:"
aws s3 ls s3://$S3_BUCKET/db-server/ || echo "   (Could not list - check permissions)"

echo "🗂️  Web Server:"
aws s3 ls s3://$S3_BUCKET/webserver/ || echo "   (Could not list - check permissions)"

echo ""
echo "🚀 Next Steps:"
echo "1. 📖 Read the deployment guide: build/deployment-ready/DEPLOYMENT_GUIDE.md"
echo "2. 🖥️  Launch DB Server EC2 with: build/deployment-ready/ec2-dbserver-userdata.sh"
echo "3. 🌐 Launch Web Server EC2 with: build/deployment-ready/ec2-webserver-userdata.sh"
echo "4. 🔧 Update DB_HOST in webserver userdata with DB server private IP"
echo ""
echo "💡 Tip: Save the deployment guide and userdata scripts for future deployments"

echo ""
echo "✅ Complete deployment preparation finished successfully!"
echo "🎉 All artifacts are ready for EC2 deployment"
