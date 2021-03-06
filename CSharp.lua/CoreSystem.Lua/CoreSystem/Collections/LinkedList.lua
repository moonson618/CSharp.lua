--[[
Copyright 2017 YANG Huan (sy.yanghuan@gmail.com).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local System = System
local define = System.define
local throw = System.throw
local each = System.each
local ArgumentNullException = System.ArgumentNullException
local InvalidOperationException = System.InvalidOperationException
local EqualityComparer = System.EqualityComparer

local getmetatable = getmetatable
local setmetatable = setmetatable
local select = select

local LinkedListNode = define("System.LinkedListNode", {
  getNext = function (this)
    local next = this.next
    if next == nil or next == this.List.head then
      return nil
    end
    return next
  end,
  getPrevious = function (this)
    local prev = this.prev
    if prev == nil or prev == this.List.head then
      return nil
    end
    return prev
  end
})

local function newLinkedListNode(list, value)
  return setmetatable({ List = list, Value = value }, LinkedListNode)
end

local function vaildateNode(this, node)
  if node == nil then
    throw(ArgumentNullException("node"))
  end
  if node.List ~= this then
    throw(InvalidOperationException("ExternalLinkedListNode"))
  end
end

local function insertNodeBefore(this, node, newNode)
  newNode.next = node
  newNode.prev = node.prev
  node.prev.next = newNode
  node.prev = newNode
  this.Count = this.Count + 1
  this.version = this.version + 1
end

local function insertNodeToEmptyList(this, newNode)
  newNode.next = newNode
  newNode.prev = newNode
  this.head = newNode
  this.Count = this.Count + 1
  this.version = this.version + 1
end

local function invalidate(this)
  this.List = nil
  this.next = nil
  this.prev = nil
end

local function remvoeNode(this, node)
  if node.next == node then
    this.head = nil
  else
    node.next.prev = node.prev
    node.prev.next = node.next
    if this.head == node then
      this.head = node.next
    end
  end
  invalidate(node)
  this.Count = this.Count - 1
  this.version = this.version + 1
end

local LinkedListEnumerator = { 
  __index = false,
  getCurrent = System.getCurrent, 
  Dispose = System.emptyFn,
  MoveNext = function (this)
    local list = this.list
    local node = this.node
    if this.version ~= list.version then
      System.throwFailedVersion()
    end
    if node == nil then
      return false
    end
    this.current = node.Value
    node = node.next
    if node == list.head then
      node = nil
    end
    this.node = node
    return true
  end
}
LinkedListEnumerator.__index = LinkedListEnumerator

local LinkedList = { 
  Count = 0, 
  version = 0,
  __ctor__ = function (this, ...)
    local len = select("#", ...)
    if len == 1 then
      local collection = ...
      if collection == nil then
        throw(ArgumentNullException("collection"))
      end
      for _, item in each(collection) do
        this:AddLast(item)
      end
    end
  end,
  getCount = function (this)
    return this.Count
  end,
  getFirst = function(this)    
    return this.head
  end,
  getLast = function (this)
    local head = this.head
    return head ~= nil and head.prev or nil
  end,
  AddAfter = function (this, node, newNode)    
    vaildateNode(this, node)
    if getmetatable(newNode) == LinkedListNode then
      vaildateNode(this, newNode)
      insertNodeBefore(this, node.next, newNode)
      newNode.List = this
    else
      local result = newLinkedListNode(node.List, newNode)
      insertNodeBefore(this, node.next, result)
      return result
    end
  end,
  AddBefore = function (this, node, newNode)
    vaildateNode(this, node)
    if getmetatable(newNode) == LinkedListNode then
      vaildateNode(this, newNode)
      insertNodeBefore(this, node, newNode)
      newNode.List = this
      if node == this.head then
        this.head = newNode
      end
    else
      local result = newLinkedListNode(node.List, newNode)
      insertNodeBefore(this, node, result)
      if node == this.head then
        this.head = result
      end
      return result
    end
  end,
  AddFirst = function (this, node)
    if getmetatable(node) == LinkedListNode then
      vaildateNode(this, node)
      if this.head == nil then
        insertNodeToEmptyList(this, node)
      else
        insertNodeBefore(this, this.head, node)
          this.head = node
        end
        node.List = this
    else
      local result = newLinkedListNode(this, node)
      if this.head == nil then
        insertNodeToEmptyList(this, result)
      else
        insertNodeBefore(this, this.head, result)
        this.head = result
      end
      return result
    end
  end,
  AddLast = function (this, node)
    if getmetatable(node) == LinkedListNode then
      vaildateNode(this, node)
      if this.head == nil then
        insertNodeToEmptyList(this, node)
      else
        insertNodeBefore(this, this.head, node)
      end
      node.List = this
    else
      local result = newLinkedListNode(this, node)
      if this.head == nil then
        insertNodeToEmptyList(this, result)
      else
        insertNodeBefore(this, this.head, result)
      end
      return result
    end
  end,
  Clear = function (this)
    local current = this.head
    while current ~= nil do
      local temp = current
      current = current.next
      invalidate(temp)
    end
    this.head = nil
    this.Count = 0
    this.version = this.version + 1
  end,
  Contains = function (this, value)
    return this:Find(value) ~= nil
  end,
  Find = function (this, value)     
    local head = this.head
    local node = head
    local comparer = EqualityComparer(t.__genericT__).getDefault()
    local equals = comparer.EqualsOf
    if node ~= nil then
      if value ~= nil then
        repeat
          if equals(comparer, node.Value, value) then
            return node
          end
          node = node.next
        until node == head
      else
        repeat 
          if node.Value == nil then
            return node
          end
          node = node.next
        until node == head
      end
    end
    return nil
  end,
  FindLast = function (this, value)
    local head = this.head
    if head == nil then return nil end
    local last = head.prev
    local node = last
    local comparer = EqualityComparer(t.__genericT__).getDefault()
    local equals = comparer.EqualsOf
    if node ~= nil then
      if value ~= nil then
        repeat
          if equals(comparer, node.Value, value) then
            return node
          end
          node = node.prev
        until node == head
      else
        repeat 
          if node.Value == nil then
            return node
          end
          node = node.prev
         until node == head
      end
    end
    return nil
  end,
  Remove = function (this, node)
    if getmetatable(node) == LinkedListNode then
      vaildateNode(this, node)
      remvoeNode(this, node)
    else
      node = this:Find(node)
      if node ~= nil then
        remvoeNode(this, node)
      end
      return false
    end
  end,
  RemoveFirst = function (this)
    local head = this.head
    if head == nil then
      throw(InvalidOperationException("LinkedListEmpty"))
    end
    remvoeNode(this, head)
  end,
  RemoveLast = function (this)
    local head = this.head
    if head == nil then
      throw(InvalidOperationException("LinkedListEmpty"))
    end
    remvoeNode(this, head.prev)
  end,
  GetEnumerator = function (this)
    return setmetatable({ list = this, version = this.version, node = this.head }, LinkedListEnumerator)
  end
}

function System.linkedListFromTable(t, T)
  assert(T)
  return setmetatable(t, LinkedList(T))
end

define("System.LinkedList", function(T) 
  return { 
  __inherits__ = { System.ICollection_1(T), System.ICollection }, 
  __genericT__ = T,
  __len = LinkedList.getCount
  }
end, LinkedList)
