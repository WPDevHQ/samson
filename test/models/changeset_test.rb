require_relative '../test_helper'

describe Changeset do
  describe "#comparison" do
    it "builds a new changeset" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal :x => "y"
    end

    it "caches" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal :x => "y"
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "z")
      Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal :x => "y"
    end

    {
      Octokit::NotFound => "Github: Not found",
      Octokit::Unauthorized => "Github: Unauthorized",
      Octokit::InternalServerError => "Github: Internal server error",
    }.each do |exception, message|
      it "catches #{exception} exceptions" do
        GITHUB.expects(:compare).raises(exception)
        comparison = Changeset.new("foo/bar", "a", "b").comparison
        comparison.error.must_equal message
      end
    end
  end

  describe "#github_url" do
    it "returns a URL to a GitHub comparison page" do
      changeset = Changeset.new("foo/bar", "a", "b")
      changeset.github_url.must_equal "https://github.com/foo/bar/compare/a...b"
    end
  end

  describe "#pull_requests" do
    let(:comparison) { OpenStruct.new }

    it "finds pull requests mentioned in merge commits" do
      c1 = OpenStruct.new(commit: OpenStruct.new(message: "Merge pull request #42"))
      c2 = OpenStruct.new(commit: OpenStruct.new(message: "Fix typo"))
      comparison.stubs(:commits).returns([c1, c2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns("yeah!")
      changeset = Changeset.new("foo/bar", "a", "b")
      changeset.pull_requests.must_equal ["yeah!"]
    end

    it "ignores invalid pull request numbers" do
      commit = OpenStruct.new(commit: OpenStruct.new(message: "Merge pull request #42"))
      comparison.stubs(:commits).returns([commit])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(nil)
      changeset = Changeset.new("foo/bar", "a", "b")

      changeset.pull_requests.must_equal []
    end
  end
end
