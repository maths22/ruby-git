require 'git/path'

module Git

  # BranchStruct = Struct.new(:refname, :name, :remote_name, :current, :worktree_path, :sha) do
  #   def remote?
  #     !remote_name.nil?
  #   end

  #   def local?
  #     remote_name.nil?
  #   end

  #   alias current? current

  #   def checked_out?
  #     !worktree_path.nil?
  #   end

  #   alias gcommit sha

  #   def exist?
  #     if local?
  #       base.lib.command('branch', 'list', name).chomp != ''
  #     else
  #       base.lib.command('branch', 'list', '-r', name).chomp != ''
  #     end

  #   end

  #   def checkout
  #     check_if_create
  #     @base.checkout(@full)
  #   end

  #   def stashes
  #     @stashes ||= Git::Stashes.new(@base)
  #   end

  #   def archive(file, opts = {})
  #     @base.lib.archive(@full, file, opts)
  #   end

  #   # g.branch('new_branch').in_branch do
  #   #   # create new file
  #   #   # do other stuff
  #   #   return true # auto commits and switches back
  #   # end
  #   def in_branch(message = 'in branch work')
  #     old_current = @base.lib.branch_current
  #     checkout
  #     if yield
  #       @base.commit_all(message)
  #     else
  #       @base.reset_hard
  #     end
  #     @base.checkout(old_current)
  #   end
  # end

  class Branch < Path

    attr_accessor :full, :remote, :name

    def initialize(base, remote, name)
      @full = name
      @base = base
      @gcommit = nil
      @stashes = nil
      @remote = Git::Remote.new(base, remote) if remote
      @name = name
    end

    def gcommit
      @gcommit ||= @base.gcommit(@full)
      @gcommit
    end

    def stashes
      @stashes ||= Git::Stashes.new(@base)
    end

    def checkout
      check_if_create
      @base.checkout(@full)
    end

    def archive(file, opts = {})
      @base.lib.archive(@full, file, opts)
    end

    # g.branch('new_branch').in_branch do
    #   # create new file
    #   # do other stuff
    #   return true # auto commits and switches back
    # end
    def in_branch(message = 'in branch work')
      old_current = @base.lib.branch_current
      checkout
      if yield
        @base.commit_all(message)
      else
        @base.reset_hard
      end
      @base.checkout(old_current)
    end

    def create
      check_if_create
    end

    def delete
      @base.lib.branch_delete(@name)
    end

    def current
      determine_current
    end

    def contains?(commit)
      !@base.lib.branch_contains(commit, self.name).empty?
    end

    def merge(branch = nil, message = nil)
      if branch
        in_branch do
          @base.merge(branch, message)
          false
        end
        # merge a branch into this one
      else
        # merge this branch into the current one
        @base.merge(@name)
      end
    end

    def update_ref(commit)
      if @remote
        @base.lib.update_ref("refs/remotes/#{@remote.name}/#{@name}", commit)
      else
        @base.lib.update_ref("refs/heads/#{@name}", commit)
      end
    end

    def to_a
      [@full]
    end

    def to_s
      @full
    end

    private

    def check_if_create
      @base.lib.branch_new(@name) rescue nil
    end

    def determine_current
      @base.lib.branch_current == @name
    end
  end

end
