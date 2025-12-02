local lnko = require("lnko")
local fs = require("lnko.fs")
local plan = require("lnko.plan")

describe("lnko", function()
    local test_dir = "/tmp/lnko-test-" .. os.time() .. "-" .. math.random(10000)

    teardown(function()
        os.execute("rm -rf " .. test_dir)
    end)

    describe("plan", function()
        it("should create empty plan", function()
            local p = plan.new()
            assert.are.equal(0, #plan.get_tasks(p))
            assert.is_false(plan.has_conflicts(p))
        end)

        it("should add tasks to plan", function()
            local p = plan.new()
            plan.add_task(p, plan.ACTION_LINK, "/target/file", "/source/file")
            assert.are.equal(1, #plan.get_tasks(p))
        end)

        it("should track conflicts", function()
            local p = plan.new()
            plan.add_conflict(p, "/some/path", "test conflict")
            assert.is_true(plan.has_conflicts(p))
            assert.are.equal(1, #plan.get_conflicts(p))
        end)
    end)

    describe("status", function()
        it("should treat empty package as not linked", function()
            local source = test_dir .. "/status_empty_source"
            local target = test_dir .. "/status_empty_target"
            os.execute("mkdir -p " .. source .. "/empty_pkg")
            os.execute("mkdir -p " .. target)
            local p = lnko.plan_link(source, "empty_pkg", target, {})
            local tasks = plan.get_tasks(p)
            assert.are.equal(0, #tasks)
        end)
    end)

    describe("link", function()
        it("should plan link for package", function()
            local source = test_dir .. "/link_plan_source"
            local target = test_dir .. "/link_plan_target"
            os.execute("mkdir -p " .. source .. "/pkg/subdir")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'file1' > " .. source .. "/pkg/file1.txt")
            os.execute("echo 'file2' > " .. source .. "/pkg/subdir/file2.txt")

            local p = lnko.plan_link(source, "pkg", target, {})
            assert.is_false(plan.has_conflicts(p))
            local tasks = plan.get_tasks(p)
            assert.is_true(#tasks > 0)
        end)

        it("should link and unlink package", function()
            local source = test_dir .. "/link_unlink_source"
            local target = test_dir .. "/link_unlink_target"
            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'file1' > " .. source .. "/pkg/file1.txt")

            lnko.link_package(source, "pkg", target, { skip = true })
            assert.is_true(fs.is_symlink(target .. "/file1.txt"))

            lnko.unlink_package(source, "pkg", target, {})
            assert.is_false(fs.exists(target .. "/file1.txt"))
        end)

        it("should have no tasks when re-linking already linked package", function()
            local source = test_dir .. "/relink_source"
            local target = test_dir .. "/relink_target"
            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'test' > " .. source .. "/pkg/file.txt")

            lnko.link_package(source, "pkg", target, { skip = true })
            assert.is_true(fs.is_symlink(target .. "/file.txt"))

            local p = lnko.plan_link(source, "pkg", target, { skip = true })
            local tasks = plan.get_tasks(p)
            assert.are.equal(0, #tasks)
        end)
    end)

    describe("tree folding", function()
        it("should fold directory into single symlink", function()
            local source = test_dir .. "/fold_single_source"
            local target = test_dir .. "/fold_single_target"
            os.execute("mkdir -p " .. source .. "/pkg/.config/app")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'config' > " .. source .. "/pkg/.config/app/settings")

            lnko.link_package(source, "pkg", target, { skip = true })
            assert.is_true(fs.is_symlink(target .. "/.config"))
        end)

        it("should unfold when adding package with shared directory", function()
            local source = test_dir .. "/fold_unfold_source"
            local target = test_dir .. "/fold_unfold_target"
            os.execute("mkdir -p " .. source .. "/pkg_a/.config/app_a")
            os.execute("mkdir -p " .. source .. "/pkg_b/.config/app_b")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'a' > " .. source .. "/pkg_a/.config/app_a/config")
            os.execute("echo 'b' > " .. source .. "/pkg_b/.config/app_b/config")

            lnko.link_package(source, "pkg_a", target, { skip = true })
            assert.is_true(fs.is_symlink(target .. "/.config"))

            lnko.link_package(source, "pkg_b", target, { skip = true })
            assert.is_true(fs.is_directory(target .. "/.config"))
            assert.is_false(fs.is_symlink(target .. "/.config"))
            assert.is_true(fs.is_symlink(target .. "/.config/app_a"))
            assert.is_true(fs.is_symlink(target .. "/.config/app_b"))
        end)
    end)

    describe("conflict detection", function()
        it("should skip conflict when linking from different source with skip option", function()
            local source1 = test_dir .. "/conflict_diff_source1"
            local source2 = test_dir .. "/conflict_diff_source2"
            local target = test_dir .. "/conflict_diff_target"

            os.execute("mkdir -p " .. source1 .. "/pkg")
            os.execute("mkdir -p " .. source2 .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'original' > " .. source1 .. "/pkg/file.txt")
            os.execute("echo 'different' > " .. source2 .. "/pkg/file.txt")

            lnko.link_package(source1, "pkg", target, { skip = true })
            assert.is_true(fs.is_symlink(target .. "/file.txt"))

            local p = lnko.plan_link(source2, "pkg", target, { skip = true })
            local tasks = plan.get_tasks(p)
            assert.are.equal(0, #tasks)
            assert.is_true(fs.symlink_points_to(target .. "/file.txt", source1 .. "/pkg/file.txt"))
        end)

        it("should detect conflict with existing regular file", function()
            local source = test_dir .. "/conflict_file_source"
            local target = test_dir .. "/conflict_file_target"

            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'source' > " .. source .. "/pkg/file.txt")
            os.execute("echo 'existing' > " .. target .. "/file.txt")

            local p = lnko.plan_link(source, "pkg", target, { skip = true })
            local tasks = plan.get_tasks(p)
            assert.are.equal(0, #tasks)
            assert.is_false(fs.is_symlink(target .. "/file.txt"))
            assert.is_true(fs.exists(target .. "/file.txt"))
        end)
    end)

    describe("stow compatibility", function()
        it("should recognize existing stow-created symlinks", function()
            local source = test_dir .. "/stow_source"
            local target = test_dir .. "/stow_target"

            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'config' > " .. source .. "/pkg/file.txt")
            os.execute("cd " .. target .. " && ln -s ../stow_source/pkg/file.txt file.txt")

            local p = lnko.plan_link(source, "pkg", target, { skip = true })
            local tasks = plan.get_tasks(p)
            assert.are.equal(0, #tasks)
        end)
    end)

    describe("edge cases", function()
        it("should handle circular symlinks gracefully", function()
            local source = test_dir .. "/circular_source"
            local target = test_dir .. "/circular_target"

            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("ln -s loop " .. source .. "/pkg/loop")

            lnko.link_package(source, "pkg", target, { skip = true })
            assert.is_true(fs.is_symlink(target .. "/loop"))
        end)

        it("should handle unicode filenames", function()
            local source = test_dir .. "/unicode_source"
            local target = test_dir .. "/unicode_target"

            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'test' > '" .. source .. "/pkg/файл.txt'")
            os.execute("echo 'test' > '" .. source .. "/pkg/文件.txt'")
            os.execute("echo 'test' > '" .. source .. "/pkg/αρχείο.txt'")

            lnko.link_package(source, "pkg", target, { skip = true })

            assert.is_true(fs.is_symlink(target .. "/файл.txt"))
            assert.is_true(fs.is_symlink(target .. "/文件.txt"))
            assert.is_true(fs.is_symlink(target .. "/αρχείο.txt"))
        end)

        it("should handle deep nested directories", function()
            local source = test_dir .. "/deep_source"
            local target = test_dir .. "/deep_target"

            os.execute("mkdir -p " .. source .. "/pkg/a/b/c/d/e/f/g/h")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'deep' > " .. source .. "/pkg/a/b/c/d/e/f/g/h/file.txt")

            lnko.link_package(source, "pkg", target, { skip = true })
            assert.is_true(fs.is_symlink(target .. "/a"))

            lnko.unlink_package(source, "pkg", target, {})
            assert.is_false(fs.exists(target .. "/a"))
        end)

        it("should handle hidden files within packages", function()
            local source = test_dir .. "/hidden_source"
            local target = test_dir .. "/hidden_target"

            os.execute("mkdir -p " .. source .. "/pkg/.hidden_dir")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'hidden' > " .. source .. "/pkg/.hidden_file")
            os.execute("echo 'nested' > " .. source .. "/pkg/.hidden_dir/.nested")

            lnko.link_package(source, "pkg", target, { skip = true })

            assert.is_true(fs.is_symlink(target .. "/.hidden_file"))
            assert.is_true(fs.is_symlink(target .. "/.hidden_dir"))
        end)

        it("should handle symlinks pointing outside source", function()
            local source = test_dir .. "/external_source"
            local target = test_dir .. "/external_target"
            local external_file = test_dir .. "/external_file.txt"

            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'external' > " .. external_file)
            os.execute("ln -s " .. external_file .. " " .. source .. "/pkg/link_to_external")

            lnko.link_package(source, "pkg", target, { skip = true })

            assert.is_true(fs.is_symlink(target .. "/link_to_external"))
        end)

        it("should handle relative source path", function()
            local base = test_dir .. "/relative_test"
            local source = base .. "/dotfiles"
            local target = base .. "/home"

            os.execute("mkdir -p " .. source .. "/bash")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'bashrc' > " .. source .. "/bash/.bashrc")

            lnko.link_package(source, "bash", target, { skip = true })

            assert.is_true(fs.is_symlink(target .. "/.bashrc"))
            assert.is_true(fs.symlink_points_to(target .. "/.bashrc", source .. "/bash/.bashrc"))
        end)

        it("should plan but fail to execute on read-only target", function()
            local source = test_dir .. "/readonly_source"
            local target = test_dir .. "/readonly_target"

            os.execute("mkdir -p " .. source .. "/pkg")
            os.execute("mkdir -p " .. target)
            os.execute("echo 'file' > " .. source .. "/pkg/file.txt")

            local p = lnko.plan_link(source, "pkg", target, { skip = true })
            assert.are.equal(1, #plan.get_tasks(p))

            os.execute("chmod 555 " .. target)
            lnko.link_package(source, "pkg", target, { skip = true })
            os.execute("chmod 755 " .. target)

            assert.is_falsy(fs.is_symlink(target .. "/file.txt"))
        end)
    end)
end)
