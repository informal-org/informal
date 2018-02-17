<template>
    <div v-bind:class="classObject" @mousedown="select" data-id="cell.id">

        Cell

    </div>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";

export default Vue.component('Cell', {
    name: 'Cell',
    props: {
        'cell': {type: Value},
    },
    computed: {
        result: function() : string {
            return this.cell.evaluate()
        },
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
        isEdit: function() : boolean {
            // return isEditMode(this.selected, this.orderIndex)
            return false;
        },
        classObject: function() : object {
            // var typeClass = "DataType--" + this.cell.type;
            var typeClass = "DataType--" + this.cell.result_type;
            var cellClass = "CellType--" + this.cell.type;
            // this.index is relative within a group.
            let classes: {[index: string]: any} =  {
                "DataRow": true,
                "DataRow--large": this.isLargeItem,
                "edit": this.isEdit,
                "list-group-item": true,
            }
            classes[typeClass] = true;
            classes[cellClass] = true;
            return classes;
        },
    },
    methods: {
        select: function(event: Event) {
            // @ts-ignore:
            if(this.isEdit) {
                // Hide this mousedown event from selector so our input boxes can be edited.
                event.stopPropagation();
            }
        }
    },
    watch: {
        isEdit: function (val) {
            if(val) {
                let el = this.$el;
                // Wait till after element is added.
                setTimeout(function() {
                    el.querySelector('.DataValue .DataInput').focus();
                }, 100);
            }
       }
    }
});
</script>

<style>
</style>