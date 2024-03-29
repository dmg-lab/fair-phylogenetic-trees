using HTTP, Gumbo, Oscar

# Small helper function, this will be in Oscar soon
function graph_from_edges(T, n::Int, edges)
    result = Graph{T}(n)
    for e in edges
        add_edge!(result, e[1], e[2])
    end
    return result
end

# The graphs are only available as images, hence we need to manually code them.
newick_dict = Dict{String, String}(
  "MC5Stairs.gif"    => "(A:1,(B:1,(C:1,D:1,E:1):1):1);",
  "5-taxa-nmc-1.gif" => "(A:1,B:1,C:1,D:1,E:1);",
  "MC5Rake.gif"      => "(A:1,B:1,(C:1,(D:1,E:1):1):1);",
  "4-taxa-mc-4.gif"  => "(A:1,(B:1,C:1,D:1):1);",
  "3-taxa-mc-2.gif"  => "(A:1,B:1,C:1);",
  "5-comb.gif"       => "(A:1,(B:1,(C:1,(D:1,E:1):1):1):1);",
  "5-taxa-nmc-3.gif" => "((A:1,B:1):1,C:1,(D:1,E:1):1);",
  "MC5Foot.gif"      => "((A:1,B:1):1,(C:1,D:1,E:1):1);",
  "5-taxa-nmc-2.gif" => "(A:1,B:1,(C:1,D:1,E:1):1);",
  "3-taxa.gif"       => "(A:1,B:1,C:1);",
  "MC5Tent.gif"      => "(A:1,B:1,C:1,(D:1,E:1):1);",
  "5-taxa-nmc-4.gif" => "((A:1,B:1):1,C:1,(D:1,E:1):1);",
  "5-taxa-mc.gif"    => "(A:1,B:1,C:1,D:1,E:1);",
  "4-taxa-mc-5.gif"  => "(A:1,B:1,C:1,D:1);",
  "MC5Crane.gif"     => "(A:1,(B:1,C:1,D:1,E:1):1);",
  "4-taxa-mc-1.gif"  => "((A:1,B:1):1,(C:1,D:1):1);",
  "giraffe.gif"      => "((A:1,B:1):1,(C:1,(D:1,E:1):1):1);",
  "MC5Cartwheel.gif" => "(A:1,B:1,(C:1,D:1,E:1):1);",
  "4-taxa-1.gif"     => "(A:1,B:1,(C:1,D:1):1);",
  "4-taxa-mc-2.gif"  => "(A:1,(B:1,(C:1,D:1):1):1);",
  "4-taxa-2.gif"     => "(A:1,B:1,C:1,D:1);",
  "4-taxa-mc-3.gif"  => "(A:1,B:1,(C:1,D:1):1);",
  "MC5Anteater.gif"  => "(A:1,(B:1,C:1,(D:1,E:1):1):1);",
  "5-fork.gif"       => "(A:1,((B:1,C:1):1,(D:1,E:1):1):1);",
  "MC5Mirror.gif"    => "((A:1,B:1):1,C:1,(D:1,E:1):1);",
  "3-taxa-mc-1.gif"  => "(A:1,(B:1,C:1):1);"
)

tree_dict = Dict{String, Oscar.PhylogeneticTree}(k => phylogenetic_tree(QQFieldElem, v) for (k, v) in newick_dict)

# Main data object
struct SmallTreeModel 
    name::String
    tree::PhylogeneticTree
    invariants::Dict{String, Union{Int, Nothing}}
    param_probability_coordinates::Vector{QQMPolyRingElem}
    param_fourier_coordinates::Vector{QQMPolyRingElem}
end

function is_model_page(content_string::String)
    m = match(r"<li><a href=\"([^\"]*)\">Singular file</a>", content_string)
    return !isnothing(m)
end

function retrieve_model(sr::String)
    content = parsehtml(sr)
    body = content.root.children[2]
    name = body.children[2].children[1].text
    invariants = extract_invariants(body)
    param1 = convert_to_polynomials(extract_code(body, "Parameterization in probability coordinates"))
    param2 = convert_to_polynomials(extract_code(body, "Parameterization in Fourier coordinates"))
    return SmallTreeModel(name, get_tree(body), invariants, param1, param2)
end

function convert_to_polynomials(list::String)
    string_vars = unique([e.match for e in eachmatch(r"[A-Za-z]\d", list)])
    result_ring,v = polynomial_ring(QQ, string_vars)
    var_dict = Dict{String, elem_type(result_ring)}([(string_vars[i] => result_ring[i]) for i in 1:length(string_vars)])
    replaced = replace(list, "\n"=>"")
    result = elem_type(result_ring)[]
    for p in split(replaced, ",")
        pp = Oscar.eval_poly(string(p), result_ring)
        push!(result, pp)
    end
    return result
end

function get_tree(body::HTMLElement)
    img = body.children[3].children[1].attributes["src"]
    if haskey(TreeDict, img)
        return TreeDict[img]
    else
        println("No tree $img")
        return img
    end
end

# Extract table of invariants
function extract_invariants(body::HTMLElement)
    table = body.children[6]
    html_keys = table.children[1].children[1]
    html_invariants = table.children[1].children[2]
    invariants = Dict{String, Union{Nothing,Int}}()
    for child in zip(html_keys.children, html_invariants.children)
        key = child[1].children[1].children[1].children[1].children[1].text
        val = child[2].children[1]
        if typeof(val) == HTMLText
            try
                invariants[key] = parse(Int, val.text)
            catch
                println("Failed to parse ", val.text)
                invariants[key] = nothing
            end
        else
            invariants[key] = nothing
        end
    end
    return invariants
end

# Get url of code file and download code
function extract_code(body::HTMLElement, ename::String)
    url_table = body.children[8]
    target = nothing
    for child in url_table.children
        label = child.children[1].children[1].text
        if label == ename
            target = child.children[1].attributes["href"]
            break
        end
    end
    !isnothing(target) || error("Could not locate $ename")
    base_url = "https://www.coloradocollege.edu/aapps/ldg/small-trees/"
    target_url = base_url * target
    result = HTTP.request("GET", target_url)
    return String(result.body)
end


# Download sample object
base_url = "https://www.coloradocollege.edu/aapps/ldg/small-trees/"
url = base_url * "small-trees_21.html"
r = HTTP.request("GET", url)
sr = String(r.body)
mod = retrieve_model(sr)




 # Small loop that can detect which URLs exist
 mods = SmallTreeModel[]
 for i in 0:30
     try
         local url = base_url * "small-trees_$i.html"
         println(url)
         local r = HTTP.request("GET", url)
         println("$i exists")
         local sr = String(r.body)
         println("Contains model? $(is_model_page(sr))")
         if is_model_page(sr)
             local mod = retrieve_model(sr)
             push!(mods, mod)
         end
     catch e
         println("$i does not exist $e")
     end
 end

new_tree_dict = Dict{String, Oscar.PhylogeneticTree{QQFieldElem}}()
for (k, v) in tree_dict
    println(k)
    new_tree_dict[k] = phylogenetic_tree(QQFieldElem, v)
end
