const std = @import("std");
const g = @import("global");
const u = @import("utils");
const mem = std.mem;

pub fn run() !u8 {
    // 1. 環境変数 PATH の取得
    const env_path = g.environ_map.get("PATH") orelse {
        try u.eprintln("not found 'PATH' in env variable");
        return 1;
    };

    // 2. 順序維持 + 重複排除のための準備
    // StringHashMap を void 型で使うことで、要素の存在チェック（Set）として機能する
    var path_map = std.StringHashMap(void).init(g.allocator);
    // 分割後のパスを格納する動的配列
    var path_list: std.ArrayList([]const u8) = .empty;

    // セミコロン「;」で分割してループ
    var it = mem.splitScalar(u8, env_path, ';');
    while (it.next()) |path| {
        // 空のパス（連続したセミコロンなど）はスキップ
        if (path.len == 0) continue;

        // まだ登録されていないパスの場合のみ、マップとリストに追加（これで順序が維持される）
        const gget = try path_map.getOrPut(path);
        if (!gget.found_existing) {
            try path_list.append(g.allocator, path);
        }
    }

    // 3. 重複を排除したパスをセミコロンで再結合
    const new_path = try mem.join(g.allocator, ";", path_list.items);

    // 4. 結果を標準出力に書き出す
    try g.stdout.writeAll(new_path);
    try g.stdout.flush();

    return 0;
}
