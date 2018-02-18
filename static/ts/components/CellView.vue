<template>
    <div v-bind:class="classObject" @mousedown="select" data-id="cell.id">
        <label class="DataLabel">{{ cell.name }}</label>
        <span class="DataValue">
            <!-- Auto-reflow to next line due to div -->
            <Result-View v-bind:value="cell.evaluate()"></Result-View>
        </span>

        <Cell-Errors v-bind:cell="cell"></Cell-Errors>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";
import * as constants from "../constants"

export default Vue.component('CellView', {
    name: 'CellView',
    props: {
        'cell': {type: Value},
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
                "list-group-item": true,
            }
            classes[typeClass] = true;
            classes[cellClass] = true;
            return classes;
        },
    },
    methods: {
        select: function(event: Event) {
            this.$store.commit("setEdit", this.cell);
        }
    }
});
</script>

<style>
</style>