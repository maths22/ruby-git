#!/usr/bin/env ruby

require 'test_helper'

class TestBranch < Test::Unit::TestCase
  def setup
    clone_working_repo
    @git = Git.open(@wdir)

    @commit = @git.object('1cc8667014381')
    @tree = @git.object('1cc8667014381^{tree}')
    @blob = @git.object('v2.5:example.txt')

    @branches = @git.branches
  end

  test '#branch_current when there are no commits' do
    in_temp_dir do
      git = Git.init('.', initial_branch: 'fizz')
      assert_equal('fizz', git.current_branch)
    end
  end

  test 'Git::Lib#branch with no args should return current branch' do
    in_temp_dir do
      git = Git.init('.', initial_branch: 'my_branch')
      File.write('file.txt', 'hello world')
      git.add('file.txt')
      git.commit('Initial commit')

      b = git.branch
      assert_equal('my_branch', b.name)
    end
  end

  test 'Git::Base#branches' do
    in_temp_dir do
      remote_git = Git.init('remote_git', initial_branch: 'master')
      File.write('remote_git/file.txt', 'hello world')
      remote_git.add('file.txt')
      remote_git.commit('Initial commit')
      remote_branches = remote_git.branches
      assert_equal(1, remote_branches.size)
      assert(remote_branches.first.current)
      assert_equal('master', remote_branches.first.name)

      # Test that remote tracking branches are handled correctly
      #
      local_git = Git.clone('remote_git/.git', 'local_git')
      local_branches = assert_nothing_raised { local_git.branches }
      assert_equal(3, local_branches.size)
      assert(remote_branches.first.current)
      local_branch_refs = local_branches.map(&:full)
      assert_include(local_branch_refs, 'master')
      assert_include(local_branch_refs, 'refs/remotes/origin/master')
      assert_include(local_branch_refs, 'refs/remotes/origin/HEAD')
    end
  end

  test 'Git::Base#branchs with detached head' do
    in_temp_dir do
      git = Git.init('.', initial_branch: 'master')
      File.write('file1.txt', 'hello world')
      git.add('file1.txt')
      git.commit('Initial commit')
      git.add_tag('v1.0.0')
      File.write('file2.txt', 'hello world')
      git.add('file2.txt')
      git.commit('Second commit')

      # This will put us in a detached head state
      git.checkout('v1.0.0')

      branches = assert_nothing_raised { git.branches }
      assert_equal(1, branches.size)
      assert_equal('master', branches.first.name)
    end
  end

  test 'Git::Lib#branches_all with worktrees' do
    in_temp_dir do
      Dir.mkdir('main_repo')
      git = Dir.chdir('main_repo') do
        Git.init('.', initial_branch: 'master').tap do |g|
          File.write('file.txt', 'hello world')
          g.add('file.txt')
          g.commit('Initial commit')
        end
      end

      git.worktree('worktree1').add
      git.worktree('worktree2').add
      git.worktree('worktree2').remove

      branches = assert_nothing_raised { git.lib.branches_all }

      master_branch = branches.find { |b| b.name == 'master' }
      assert_equal(true, master_branch.current?)
      assert_equal(true, master_branch.checked_out?)

      worktree1_branch = branches.find { |b| b.name == 'worktree1' }
      assert_equal(false, worktree1_branch.current?)
      assert_equal(true, worktree1_branch.checked_out?)

      worktree2_branch = branches.find { |b| b.name == 'worktree2' }
      assert_equal(false, worktree2_branch.current?)
      assert_equal(false, worktree2_branch.checked_out?)
    end
  end

  def test_branches_local
    bs = @git.branches.local
    assert(bs.size > 4)
  end

  def test_branches_remote
    bs = @git.branches.remote
    assert_equal(1, bs.size)
  end

  def test_branches_single
    branch = @git.branches[:test_object]
    assert_equal('test_object', branch.name)

    %w{refs/remotes/working/master}.each do |branch_name|
      branch = @git.branches[branch_name]

      assert_equal('refs/remotes/working/master', branch.name)
      assert_equal('refs/remotes/working/master', branch.full)
      assert_equal('working', branch.remote.name)
      assert_equal('+refs/heads/*:refs/remotes/working/*', branch.remote.fetch_opts)
      assert_equal('../working.git', branch.remote.url)
    end
  end

  def test_true_branch_contains?
    assert(@git.branch('git_grep').contains?('master'))
  end

  def test_false_branch_contains?
    assert(!@git.branch('master').contains?('git_grep'))
  end

  def test_branch_commit
    assert_equal(270, @git.branches[:test_branches].gcommit.size)
  end

  def test_branch_create_and_switch
    in_bare_repo_clone do |git|
      assert(!git.branch('new_branch').current)
      git.branch('other_branch').create
      assert(!git.branch('other_branch').current)
      git.branch('new_branch').checkout
      assert(git.branch('new_branch').current)

      assert_equal(1, git.branches.select { |b| b.name == 'new_branch' }.size)

      new_file('test-file1', 'blahblahblah1')
      new_file('test-file2', 'blahblahblah2')
      new_file('.test-dot-file1', 'blahblahblahdot1')
      assert(git.status.untracked.assoc('test-file1'))
      assert(git.status.untracked.assoc('.test-dot-file1'))

      git.add(['test-file1', 'test-file2'])
      assert(!git.status.untracked.assoc('test-file1'))

      git.reset
      assert(git.status.untracked.assoc('test-file1'))
      assert(!git.status.added.assoc('test-file1'))

      assert_raise Git::FailedError do
        git.branch('new_branch').delete
      end
      assert_equal(1, git.branches.select { |b| b.name == 'new_branch' }.size)

      git.branch('master').checkout
      git.branch('new_branch').delete
      assert_equal(0, git.branches.select { |b| b.name == 'new_branch' }.size)

      git.checkout('other_branch')
      assert(git.branch('other_branch').current)

      git.checkout('master')
      assert(!git.branch('other_branch').current)

      git.checkout(@git.branch('other_branch'))
      assert(git.branch('other_branch').current)
    end
  end

  def test_branch_update_ref
    in_temp_dir do |path|
      git = Git.init
      File.write('foo','rev 1')
      git.add('foo')
      git.commit('rev 1')
      git.branch('testing').create
      File.write('foo','rev 2')
      git.add('foo')
      git.commit('rev 2')
      git.branch('testing').update_ref(git.revparse('HEAD'))

      # Expect the call to Branch#update_ref to pass the full ref name for the
      # of the testing branch to Lib#update_ref
      assert_equal(git.revparse('HEAD'), git.revparse('refs/heads/testing'))
    end
  end
end
