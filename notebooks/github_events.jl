### A Pluto.jl notebook ###
# v0.14.0

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 1ace96da-925d-11eb-080f-71303ed541c6
using Plots

# ╔═╡ 11e1e900-925d-11eb-1f84-a544b006315b
using DataFrames

# ╔═╡ bb3bf14a-925c-11eb-254a-5b5ac58203e6
@bind ghevents html"<p>Connected!</p>"

# ╔═╡ 6e949ca8-81ef-4c9e-be22-20412200539c
macro noop(_) end

# ╔═╡ d36f57a4-925c-11eb-3724-b9b32c32f5ae
begin
	if !isdefined(Main, :events)
		@eval Main events = []
	end
	if ghevents !== missing
		push!(Main.events, ghevents)
	end
	agg_events = Main.events
end;

# ╔═╡ 1c0264d6-ead5-48f8-afb6-1c11d28f7f5c
push_events = filter(event -> event["type"] == "PushEvent", agg_events);

# ╔═╡ 524402ff-8586-4842-b3e6-ff405f90fb74
struct CommitEvent
	author::String
	
	# the avatar url is the one of the pusher for simplicity
	avatar_url::String 

	message::String
	repo_name::String
end

# ╔═╡ 0ead955d-08de-4a40-8f00-ed05ca729cdf
begin
	function push_events_to_commits(push_event)
		author = push_event["actor"]["display_login"]
		avatar_url = push_event["actor"]["avatar_url"]
		repo_name = push_event["repo"]["name"]
		messages = map(x -> x["message"], push_event["payload"]["commits"])
		
		CommitEvent.(author, avatar_url, messages, repo_name)
	end
	commit_events = collect(Iterators.flatten(map(push_events_to_commits, push_events)))
end;

# ╔═╡ 77557d7a-7185-4de8-acad-d4256a9ededf
md"""
### 10 last commits from GitHub
"""

# ╔═╡ c765464f-2d84-40b3-a310-7c7925812e77
commit_events[length(commit_events)-10:end]

# ╔═╡ f51cdca8-8fef-4b45-838b-44399ce074b3
begin
	function to_html_string(commit::CommitEvent)
		"""
		<div style="padding: 10px; display: flex">
		<img src="$(commit.avatar_url)" height="24" width="24"/>
		<p style="margin-left: 10px">
			$(commit.message) <span style="color: gray;">@ <a target="_blank" style="color: #aaa" href="https://github.com/$(commit.repo_name)">$(commit.repo_name)</a></span> from $(commit.author)
		</p>
		</div>
		"""
	end
	function Base.show(io::IO, ::MIME"text/html", commit::CommitEvent)
		html_val = to_html_string(commit)

		print(io, html_val)
	end
	function Base.show(io::IO, ::MIME"text/html", commits::Vector{CommitEvent})
		print(io, "<ul>")
		for commit in commits
			print(io, to_html_string(commit))
		end
		print(io, "</ul>")
	end
end

# ╔═╡ Cell order:
# ╠═bb3bf14a-925c-11eb-254a-5b5ac58203e6
# ╠═6e949ca8-81ef-4c9e-be22-20412200539c
# ╠═d36f57a4-925c-11eb-3724-b9b32c32f5ae
# ╠═1c0264d6-ead5-48f8-afb6-1c11d28f7f5c
# ╠═524402ff-8586-4842-b3e6-ff405f90fb74
# ╠═0ead955d-08de-4a40-8f00-ed05ca729cdf
# ╟─77557d7a-7185-4de8-acad-d4256a9ededf
# ╠═c765464f-2d84-40b3-a310-7c7925812e77
# ╠═f51cdca8-8fef-4b45-838b-44399ce074b3
# ╠═1ace96da-925d-11eb-080f-71303ed541c6
# ╠═11e1e900-925d-11eb-1f84-a544b006315b
