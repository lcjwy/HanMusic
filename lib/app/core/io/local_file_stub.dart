/// Web 平台无法访问本地文件系统，统一返回不存在。
bool localFileExists(String path) => false;

/// Web 平台无文件可删，空实现。
void localFileDelete(String path) {}
