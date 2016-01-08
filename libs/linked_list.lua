linked_list = {}
linked_list.__index = linked_list

function linked_list.new()
    return {head = nil, tail = nil, count = 0}
end

function linked_list.append(list, item)
    local node = { value = item, next = nil, prev = nil }
    if list.head == nil then
        list.head = node
        list.tail = node
    else
        node.prev = list.tail
        list.tail.next = node
        list.tail = node
    end
    list.count = list.count + 1
end

function linked_list.pop(list)
    if list.count == 0 then
        return nil
    elseif list.count == 1 then
        local item = list.head.value
        list.head = nil
        list.tail = nil
        list.count = 0
        return item
    else
        local old_head = list.head
        list.head = old_head.next
        list.head.prev = nil
        list.count = list.count - 1
        return old_head.value
    end
end

function linked_list.remove(list, node)
    if list.count == 1 then
        list.head = nil
        list.tail = nil
        list.count = 0
    else
        if node.prev ~= nil then
            node.prev.next = node.next
        end
        if node.next ~= nil then
            node.next.prev = node.prev
        end
        list.count = list.count - 1
    end
end

function linked_list.iterator(list)
    local iterator = {item = list.head}
    function iterator.next()
        return iterator:next_node().value
    end

    function iterator.next_node()
        local cur = iterator.item
        iterator.item = iterator.item.next
        return cur
    end

    function iterator.has_next()
        return iterator.item ~= nil
    end
    return iterator
end
