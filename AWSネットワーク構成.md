# AWS ネットワーク構成
## ネットワーク構成図

```
Internet
    |
Internet Gateway
    |
VPC (10.0.0.0/16)
    |
    +-- Public Subnet (10.0.1.0/24)
    |   |
    |   +-- NAT Gateway
    |   +-- Web Server EC2 (10.0.1.100)
    |
    +-- Private Subnet (10.0.2.0/24)
        |
        +-- DB Server EC2 (10.0.2.100)
```

## ネットワーク設定詳細

| リソース | 設定値 | 説明 |
|----------|--------|------|
| VPC | 10.0.0.0/16 | VPC |
| パブリックサブネット | 10.0.1.0/24 | Webサーバー用 |
| プライベートサブネット | 10.0.2.0/24 | DBサーバー用 |
| Internet Gateway | - | インターネット接続 |
| NAT Gateway | パブリックサブネット内 | プライベートサブネットのアウトバウンド通信 |

## IAM権限
### EC2インスタンス用IAMロール
EC2インスタンスがS3からパッケージをダウンロードするために、以下の権限を持つIAMロールを作成し、EC2インスタンスにアタッチしてください。

必要な権限（IAMポリシー）:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::dbconnectiontestapp-deployment",
                "arn:aws:s3:::dbconnectiontestapp-deployment/*"
            ]
        }
    ]
}
```

## EC2インスタンス（Webサーバー）のプロビジョニング
ユーザーデータとして、`deployment/ec2-dbserver-userdata.sh`をアップロードして下さい。

## CloudShellからSSH接続する方法

### 前提条件
1. EC2インスタンスにキーペア（.pemファイル）が設定されている
2. セキュリティグループでSSH（ポート22）が許可されている
3. CloudShellに秘密鍵ファイルがアップロードされている

### キーペアファイルの準備
```bash
# CloudShellに秘密鍵をアップロードした後、権限を設定
chmod 400 your-key-pair.pem

# キーペアファイルの確認
ls -la *.pem
```

### WebサーバーEC2への接続
#### パブリックIPアドレスを使用したSSH接続
```bash
# 直接IPアドレスを指定して接続
ssh -i "your-key-pair.pem" ec2-user@10.0.1.100
```

### DBサーバーEC2への接続
#### Webサーバー経由での接続（プライベートサブネットの場合）
```bash
# まずWebサーバーに接続
ssh -i "your-key-pair.pem" ec2-user@10.0.1.100

# Webサーバー内からDBサーバーにSSH接続（キーペアが必要）
ssh -i "your-key-pair.pem" ec2-user@10.0.2.100
```

### 接続後の確認コマンド
```bash
# サーバーの状態確認
sudo systemctl status docker
docker ps

# Webサーバーでのアプリケーション確認
curl http://localhost:3000

# DBサーバーでのデータベース確認
docker exec -it mysql_container mysql -u root -p
```

### 注意事項
- CloudShellに秘密鍵ファイル（.pem）をアップロードする必要があります
- セキュリティグループでSSH（ポート22）が許可されている必要があります
- プライベートサブネット内のDBサーバーには、Webサーバーを踏み台として接続します
- 接続時にはキーペアファイルの権限を400に設定してください（`chmod 400 your-key-pair.pem`）
- CloudShellのセッションタイムアウト（通常20分）に注意してください