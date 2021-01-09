#######################################################################
# Macros for printing information depending on verbosity
#
# ASSUMPTION: the package defines variable `VERBOSE`
#######################################################################

const STATUS_BEGIN = "..."
const STATUS_END   = " completed"

# If verbose, prints information about the start and completion of
# of `action` named `name`
macro status(name, action)
    quote
        @statusb $(esc(name))
        tmp = $(esc(action))
        @statuse $(esc(name))
        tmp
    end
end

# if verbose, prints information `name`
macro status(name)
    :(if VERBOSE ; @info($(esc(name))) end)
end

# If verbose, prints information about the start of `name`
macro statusb(name)
    :(if VERBOSE ; @info($(esc(name)) * $STATUS_BEGIN) end)
end

# If verbose, prints information about the completion of `name`
macro statuse(name)
    :(if VERBOSE ; @info($(esc(name)) * $STATUS_END) end)
end

# If debug mode, performs action
macro debugonly(action)
    :(if DEBUG ; $(esc(action)) end)
end
