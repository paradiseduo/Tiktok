# Tiktok
Tiktok是一个AST扫描器，用于发现敏感函数调用链，方便通过静态扫描的方式提前做隐私合规水位预警

## 使用方法
```bash
❯ ./Tiktok -h                                                                                                                                                                                                                                                                                  at 16:45:14
OVERVIEW: Tiktok v1.0.0

tiktok is a tool which scan indexDB AST to find api which one used.

USAGE: tiktok <index-db-path> <api-path> <out-put-path>

ARGUMENTS:
  <index-db-path>         The indexDB path for Tiktok.
  <api-path>              The api json file path for Tiktok.
  <out-put-path>          The output path for Tiktok.

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.
```

## 举个例子
```bash
❯ ./Tiktok IndexDB的路径 需要扫描的api(JSON文件，对格式有要求) 结果输出目录
❯ ./Tiktok /Users/admin/Library/Developer/Xcode/DerivedData/Tiktok-cmoxrmqwmupadmaqlqrwfmiorwxi/Index.noindex/DataStore /Users/admin/Desktop/Tiktok/apis.json /Users/admin/Desktop/tiktok_out
```
