# EmbyTok Flutter v1.1.0 - 验证清单（Checklist）

## 第一阶段：认证与网络层验证

- [ ] **C-1.1**: ApiClient 正确注入 `X-Emby-Authorization` 头
  - [ ] 格式为：`Emby UserId="...", Client="EmbyTok", Device="Mobile", DeviceId="...", Version="1.0.0"`
  - [ ] 每个请求都包含
  - [ ] DeviceId 是稳定且持久化的 UUID

- [ ] **C-1.2**: ApiClient 正确注入 `X-Emby-Token` 头（登录后）
  - [ ] 登录成功后所有请求携带 `X-Emby-Token: <access_token>`
  - [ ] Token 在 401 时自动清除并重定向到登录页

- [ ] **C-1.3**: 请求头包含 `Content-Type: application/json`
  - [ ] POST 请求的 data 正确序列化为 JSON
  - [ ] GET 请求 Accept 头为 `application/json`

- [ ] **C-1.4**: 超时设置合理
  - [ ] connectTimeout ≤ 15s
  - [ ] receiveTimeout ≤ 30s

---

## 第二阶段：登录流程验证

- [ ] **C-2.1**: 登录请求构造正确
  - [ ] POST 到 `/Users/AuthenticateByName`
  - [ ] Body: `{"Username": "...", "Pw": "..."}`
  - [ ] 未携带 Token（登录前没有）
  - [ ] 携带 `X-Emby-Authorization` 头

- [ ] **C-2.2**: 登录响应解析正确
  - [ ] 解析 `User.Id` 为 UserId
  - [ ] 解析 `AccessToken` 为 Token
  - [ ] 解析 `User.Name` 为用户名
  - [ ] 解析 `ServerId` 为服务器ID

- [ ] **C-2.3**: 登录信息持久化
  - [ ] emby_server_url 保存在 shared_preferences
  - [ ] user_id 保存
  - [ ] access_token 保存
  - [ ] server_id 保存

- [ ] **C-2.4**: 登录错误处理
  - [ ] 401 显示"认证失败，请检查用户名或密码"
  - [ ] 网络错误显示"无法连接到服务器：请检查地址和网络"
  - [ ] 超时显示"请求超时，请重试"
  - [ ] 500 显示"服务器错误（状态码）"

---

## 第三阶段：服务器地址自动补全验证

- [ ] **C-3.1**: 输入格式自动补全
  - [ ] `192.168.1.100` → `http://192.168.1.100:8096`
  - [ ] `192.168.1.100:8096` → `http://192.168.1.100:8096`
  - [ ] `http://192.168.1.100` → `http://192.168.1.100:8096`
  - [ ] `https://emby.example.com` → 保持不变
  - [ ] `http://192.168.1.100:8096/emby` → 保持不变（支持 /emby 前缀）

- [ ] **C-3.2**: 服务器验证前检测
  - [ ] 提交前尝试 `GET /System/Info/Public`
  - [ ] 失败时显示"无法连接到服务器，请检查地址"
  - [ ] 成功显示绿色对勾

---

## 第四阶段：媒体库列表验证

- [ ] **C-4.1**: 获取媒体库列表
  - [ ] 调用 `GET /Library/VirtualFolders`
  - [ ] 解析 `Items` 数组中的每个条目的 `Id` 和 `Name`
  - [ ] 显示库名和类型

- [ ] **C-4.2**: 自动选中第一个库
  - [ ] 加载完成后自动选中第一个非空库
  - [ ] 选中后自动加载该库的视频列表

- [ ] **C-4.3**: 库切换交互
  - [ ] 点击不同库切换视频列表
  - [ ] 当前选中库高亮显示

---

## 第五阶段：视频列表获取验证

- [ ] **C-5.1**: 请求参数正确
  - [ ] `ParentId=<library_id>`
  - [ ] `Recursive=true`
  - [ ] `IncludeItemTypes=Movie,Episode,Video,MusicVideo`
  - [ ] `Fields=Overview,Genres,CommunityRating,ProductionYear,RuntimeTicks,UserData`
  - [ ] `SortBy=PremiereDate,ProductionYear,SortName` 或 `DateCreated`
  - [ ] `SortOrder=Descending`
  - [ ] `StartIndex=0` & `Limit=20`

- [ ] **C-5.2**: 分页加载正确
  - [ ] 每次请求返回 20 条
  - [ ] TotalRecordCount 正确解析
  - [ ] `StartIndex + Limit >= TotalRecordCount` 停止加载
  - [ ] 滑动到底部自动加载下一页

- [ ] **C-5.3**: 加载状态正确
  - [ ] 首次加载显示 loading
  - [ ] 错误显示错误信息和重试按钮
  - [ ] 空状态显示"没有内容"

---

## 第六阶段：媒体项模型验证

- [ ] **C-6.1**: MediaItem 解析正确
  - [ ] `Id` 解析为 item.id
  - [ ] `Name` 解析为 item.title
  - [ ] `RuntimeTicks` → 秒：`ticks / 10000000`
  - [ ] `Overview` 解析为 item.overview
  - [ ] `ProductionYear` 解析为 item.year
  - [ ] `CommunityRating` 解析为 item.rating
  - [ ] `UserData.IsFavorite` 解析为 item.isFavorite

- [ ] **C-6.2**: 缩略图地址生成正确
  - [ ] `thumbnailUrl = {server_url}/Items/{id}/Images/Primary?MaxWidth=800&Format=jpg`
  - [ ] 图片正确加载

- [ ] **C-6.3**: 播放地址生成正确
  - [ ] `playbackUrl = {server_url}/Videos/{id}/stream?api_key={token}`
  - [ ] 或使用请求头 `X-Emby-Token: {token}`
  - [ ] 视频可播放

---

## 第七阶段：视频播放验证

- [ ] **C-7.1**: 视频地址正确
  - [ ] `/Videos/{id}/stream` 地址返回视频流
  - [ ] Token 作为 URL 参数或请求头传递

- [ ] **C-7.2**: 视频播放器初始化正确
  - [ ] `VideoPlayerController.networkUrl()` 使用正确的 URL
  - [ ] `httpHeaders` 携带 `X-Emby-Token`
  - [ ] 自动播放当前页视频

- [ ] **C-7.3**: 手势交互正确
  - [ ] 单击播放/暂停
  - [ ] 双击收藏/取消收藏
  - [ ] 长按加速播放（2x）
  - [ ] 水平拖拽进度微调

---

## 第八阶段：搜索功能验证

- [ ] **C-8.1**: 搜索请求正确
  - [ ] `GET /Items?SearchTerm=<query>&Recursive=true&...`
  - [ ] 300ms 防抖延迟

- [ ] **C-8.2**: 搜索结果显示
  - [ ] 列表项显示缩略图 + 标题 + 时长
  - [ ] 点击打开播放页

- [ ] **C-8.3**: 搜索历史保存
  - [ ] 最近 10 条搜索记录
  - [ ] 点击历史项直接搜索

---

## 第九阶段：收藏功能验证

- [ ] **C-9.1**: 收藏切换
  - [ ] 点击 ❤️ 按钮
  - [ ] `POST /Users/{user_id}/FavoriteItems/{item_id}` 添加
  - [ ] `DELETE /Users/{user_id}/FavoriteItems/{item_id}` 取消
  - [ ] 乐观更新本地状态
  - [ ] 失败时回滚并显示错误

- [ ] **C-9.2**: 收藏列表
  - [ ] `GET /Items?Filters=IsFavorite&...`
  - [ ] 左滑删除

---

## 第十阶段：观看历史与播放进度同步

- [ ] **C-10.1**: 播放进度上报
  - [ ] 每 30 秒或进度变化超过阈值时 `POST /Users/{user_id}/PlayingItems/{item_id}/Progress`
  - [ ] 播放完成 `POST /Users/{user_id}/PlayingItems/{item_id}/Stopped`

- [ ] **C-10.2**: 本地历史保存
  - [ ] 保存到 shared_preferences
  - [ ] 显示最近观看列表

---

## 第十一阶段：错误处理与 Token 过期

- [ ] **C-11.1**: 401 自动跳登录
  - [ ] 检测到 401 响应
  - [ ] 清除本地 Token
  - [ ] 跳转 LoginView

- [ ] **C-11.2**: 错误消息友好
  - [ ] 中文错误信息
  - [ ] 包含错误原因
  - [ ] 包含建议操作

---

## 第十二阶段：多服务器管理（可选）

- [ ] **C-12.1**: 多服务器配置
  - [ ] 添加服务器
  - [ ] 切换服务器
  - [ ] 删除服务器
  - [ ] 每个服务器独立保存 Token 和用户信息

---

## 总体验收检查

- [ ] 所有 P0 任务完成
- [ ] 所有 P1 任务完成
- [ ] 所有核心 API 请求成功（200/204
- [ ] 所有核心页面可以流畅浏览
- [ ] 所有错误情况有友好提示
- [ ] Android 真机测试通过
- [ ] iOS 真机测试通过（如目标平台
- [ ] 代码审查通过
- [ ] 无明显内存泄漏
- [ ] 无重复的控制器未释放
