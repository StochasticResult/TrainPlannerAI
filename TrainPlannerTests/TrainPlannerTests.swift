//
//  TrainPlannerTests.swift
//  TrainPlannerTests
//
//  Created by Yuri Zhang on 8/20/25.
//

import Testing
@testable import TrainPlanner

struct TrainPlannerTests {

    @Test func rawProcessor_add_update_delete() async throws {
        let store = ChecklistStore()
        let manager = TaskManager(store: store)
        let processor = RawInputProcessor(manager: manager)

        // 1) ADD
        let addJSON = processor.process("ADD: title=Buy milk; start_date=2025-08-25; start_time=09:00; priority=high; tags=grocery,urgent; enable_due_date=true; due_date=2025-08-25; due_time=18:00; is_reminder=true; reminder_time=2025-08-25 18:00; reminder_advance=15")
        struct Resp: Decodable { let operation: String; let result: String; let task: BackendTask?; let error: String? }
        let addResp = try #require(try? JSONDecoder().decode(Resp.self, from: Data(addJSON.utf8)))
        #expect(addResp.operation == "ADD")
        #expect(addResp.result == "success")
        let created = try #require(addResp.task)
        #expect(created.title == "Buy milk")
        #expect(created.priority == "high")
        #expect(created.enable_due_date == true)

        // 2) UPDATE（标题）
        let updJSON = processor.process("UPDATE: task_id=\(created.task_id); title=Buy bread")
        let updResp = try #require(try? JSONDecoder().decode(Resp.self, from: Data(updJSON.utf8)))
        #expect(updResp.operation == "UPDATE")
        #expect(updResp.result == "success")
        #expect(updResp.task?.title == "Buy bread")

        // 3) DELETE
        let delJSON = processor.process("DELETE: task_id=\(created.task_id)")
        let delResp = try #require(try? JSONDecoder().decode(Resp.self, from: Data(delJSON.utf8)))
        #expect(delResp.operation == "DELETE")
        #expect(delResp.result == "success")

        // 4) 错误：重复与截止冲突
        let badJSON = processor.process("ADD: title=Repeat test; start_date=2025-08-25; repeat_rule=daily; enable_due_date=true; due_date=2025-08-26")
        let badResp = try #require(try? JSONDecoder().decode(Resp.self, from: Data(badJSON.utf8)))
        #expect(badResp.result == "fail")
        #expect(badResp.error?.contains("互斥") == true)
    }

}
