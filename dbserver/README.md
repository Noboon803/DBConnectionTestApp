# DBサーバーのデプロイガイド
## デプロイ手順
### STEP1　 : パッケージのビルド
実行後、`build/db-server-package/` ディレクトリに、S3へアップロードするパッケージファイルが作成されます。

```bash
# プロジェクトルートディレクトリで実行
cd {プロジェクトルートディレクトリパス}/DBConnectionTestApp

# DBサーバーパッケージをビルド
./deployment/build-and-package-db.sh
```
</br>

### STEP2 : S3へのパッケージファイルアップロード
STEP1で作成した、`build/db-server-package/` ディレクトリ下のすべてのファイルをS3にアップロードして下さい。
</br>

### STEP3 : EC2インスタンスの起動
EC2インスタンス(DBサーバー)を起動する
</br>

### STEP4 : デプロイメントの確認
WebサーバーからSSH接続して、DBサーバーのデプロイメント状況を確認します。

```bash
# WebサーバーからDBサーバーにSSH接続
ssh -i {秘密鍵ファイルパス} ec2-user@{DBサーバーのプライベートIP}

# DBサーバーでの確認作業
# 1. パッケージファイルの配置確認
ls -la /opt/mysql/

# 2. Dockerコンテナの起動状況確認
docker ps

# 3. MySQLサービスの動作確認
cd /opt/mysql
./manage-db.sh status

# 4. ネットワーク接続確認（ポート3306リッスン状況）
netstat -tlnp | grep 3306

# 5. ログの確認
docker logs mysql-db
```
</br>

### STEP5 : DB接続テスト
```bash
# DBサーバーインスタンス内で実行
cd /opt/mysql

# DB管理スクリプトでステータス確認
./manage-db.sh status

# MySQL接続テスト
./manage-db.sh shell
```

