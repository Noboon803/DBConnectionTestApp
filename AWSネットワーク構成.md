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