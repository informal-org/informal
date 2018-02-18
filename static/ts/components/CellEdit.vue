<template>
    <div v-bind:class="classObject" data-id="cell.id">
        <DestructBtn v-bind:cell="cell"></DestructBtn>

        <span class="DataLabel">
            <label>Name</label>
            <br>
            <input maxlength="20" v-model="cell.name" placeholder="Name..."/>
        </span>
        <span class="DataValue">
            <label>Value</label>
            <template v-if="isLargeItem">
                <textarea v-model="cell.expr" class="DataInput"></textarea>
            </template>
            <template v-else>
                <input type="text" placeholder="Value" v-model="cell.expr" class="DataInput" autofocus/>
                
                <template v-if="cell.isArrResult()">
                    <Result-View v-bind:value="cell._result"></Result-View>
                </template>
                <template v-else>
                    <p>{{ cell.toString() }}</p>
                </template>
                    
            </template>
        </span>

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
            // TODO: Check if text is long or not
            if(this.cell.type === "object"){
                return true;
            } else if(this.cell.type === "text" && this.cell.expr.length > 100){
                return true;
            }
            // return false;
            return this.cell.expr.toString().length > 50;
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
            }
            classes[typeClass] = true;
            classes[cellClass] = true;
            return classes;
        },
    },
});
</script>

<style>
</style>