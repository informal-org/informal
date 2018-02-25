<template>
    <div v-bind:class="classObject" data-id="cell.id" @click="blockClick">
        <span class="DataLabel">
            <label>Name</label>
            <br>
            <input maxlength="20" v-model="cell.name" placeholder="Name..."/>
        </span>
        <span>
            <template v-if="cell.type == 'group'">
                <Group-View :key="cell.id" v-bind:group="cell"></Group-View>
            </template>
            <template v-else-if="cell.type == 'table'">
                <Cell-Table :key="cell.id" v-bind:table="cell"></Cell-Table>
            </template>
            <template v-else>
                <br>
                <label>Value</label>
                <template v-if="isLargeItem">
                    <textarea v-model="cell.expr" class="DataInput"></textarea>
                </template>
                <template v-else>
                    <input type="text" placeholder="Value" v-model="cell.expr" class="DataInput" autofocus/>
                    
                    <Result-View v-bind:cell="cell"/>
                </template>
            </template>

        </span>

        <DestructBtn v-bind:cell="cell"></DestructBtn>
        <Button class="btn btn-primary btn-md pull-right">Save</Button>

        <Cell-Errors v-bind:cell="cell"></Cell-Errors>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";
import * as constants from "../constants"

export default Vue.component('CellEdit', {
    name: 'CellEdit',
    props: {
        'cell': { type: Value },
    },
    data: () => {
        return {
            'constants': constants
        }
    },
    computed: {
        isLargeItem: function() : boolean {
            if(this.cell._expr_type === "STR" && this.cell.expr.length > 50){
                return true;
            }
            return false;
        },
        classObject: function() : object {
            // var typeClass = "DataType--" + this.cell.type;
            var typeClass = "DataType--" + this.cell._result_type;
            var cellClass = "CellType--" + this.cell.type;
            // this.index is relative within a group.
            let classes: {[index: string]: any} =  {
                "DataRow": true,
                "DataRow--large": this.isLargeItem,
                "edit": true,
                "list-group-item": true,
                "DataRow--rootChild": this.cell.isRootChild()
            }
            classes[typeClass] = true;
            classes[cellClass] = true;
            return classes;
        },
    },
    methods: {
        blockClick: function(e: Event) {
            // Block click from propagating upwards and selecing something else while you're editing.
            e.stopPropagation();
        }
    }
});
</script>

<style>
</style>